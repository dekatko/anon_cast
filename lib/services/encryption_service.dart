import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

import '../models/conversation_key.dart';

/// Result of encrypting a message: ciphertext and IV (both base64).
/// Use these when uploading to Firestore; never store plaintext on server.
class EncryptedMessage {
  const EncryptedMessage({
    required this.encryptedContent,
    required this.iv,
  });

  final String encryptedContent;
  final String iv;
}

/// Thrown when encryption/decryption or key operations fail (missing key, bad data, etc.).
class EncryptionServiceException implements Exception {
  const EncryptionServiceException(this.message, {this.cause, this.conversationId});

  final String message;
  final Object? cause;
  final String? conversationId;

  @override
  String toString() =>
      'EncryptionServiceException: $message'
      '${conversationId != null ? ' (conversationId: $conversationId)' : ''}'
      '${cause != null ? ' | cause: $cause' : ''}';
}

/// Abstraction for storing conversation keys (production: Hive; tests: in-memory).
abstract interface class ConversationKeyStorage {
  Future<void> store(String conversationId, ConversationKey key);
  Future<ConversationKey?> get(String conversationId);
  Future<bool> has(String conversationId);
  Future<void> delete(String conversationId);
}

/// Stores conversation keys in Hive. Keys never leave the device.
class HiveConversationKeyStorage implements ConversationKeyStorage {
  HiveConversationKeyStorage({String boxName = 'conversation_keys'}) : _boxName = boxName;
  final String _boxName;
  Box<ConversationKey>? _box;

  Future<Box<ConversationKey>> _open() async {
    _box ??= await Hive.openBox<ConversationKey>(_boxName);
    return _box!;
  }

  @override
  Future<void> store(String conversationId, ConversationKey key) async {
    final box = await _open();
    await box.put(conversationId, key);
  }

  @override
  Future<ConversationKey?> get(String conversationId) async {
    final box = await _open();
    return box.get(conversationId);
  }

  @override
  Future<bool> has(String conversationId) async {
    final box = await _open();
    return box.containsKey(conversationId);
  }

  @override
  Future<void> delete(String conversationId) async {
    final box = await _open();
    await box.delete(conversationId);
  }
}

/// Zero-knowledge encryption: AES-256 CBC (PointyCastle), keys only in Hive, IV per message.
/// Encrypt before upload to Firestore; decrypt after download using local keys.
/// Uses PointyCastle for AES-CBC (the `encrypt` package conflicts with pointycastle ^4.0.0).
class EncryptionService {
  EncryptionService({
    ConversationKeyStorage? keyStorage,
    Logger? logger,
  })  : _keyStorage = keyStorage ?? HiveConversationKeyStorage(),
        _log = logger ?? Logger();

  final ConversationKeyStorage _keyStorage;
  final Logger _log;

  static const int _aesKeyLengthBytes = 32;
  static const int _ivLengthBytes = 16;
  static const int _pbkdf2Iterations = 10000;
  static const int _pbkdf2KeyLength = 32;
  static const int _emptySentinel = 0xff;

  // --- Key management (Hive only) ---

  /// Generates a new random AES-256 key for a conversation.
  /// Returns the key as base64 (suitable for [storeKeyLocally]).
  Future<String> generateConversationKey() async {
    try {
      final key = _secureRandomBytes(_aesKeyLengthBytes);
      final base64Key = base64Encode(key);
      _log.d('EncryptionService: generated new conversation key');
      return base64Key;
    } catch (e, st) {
      _log.e('EncryptionService: generateConversationKey failed', error: e, stackTrace: st);
      throw EncryptionServiceException('Failed to generate key', cause: e);
    }
  }

  /// Saves [key] (base64) for [conversationId] in Hive. Never sends to Firestore.
  Future<void> storeKeyLocally(String conversationId, String key) async {
    if (conversationId.isEmpty) {
      throw EncryptionServiceException('conversationId must not be empty.', conversationId: conversationId);
    }
    _validateBase64Key(key);
    try {
      final now = DateTime.now();
      await _keyStorage.store(
        conversationId,
        ConversationKey(id: conversationId, key: key, createdAt: now, lastRotated: now),
      );
      _log.d('EncryptionService: stored key locally for $conversationId');
    } catch (e, st) {
      _log.e('EncryptionService: storeKeyLocally failed', error: e, stackTrace: st);
      throw EncryptionServiceException(
        'Failed to store key: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Retrieves the key for [conversationId] from Hive, or null if not found.
  Future<String?> getKeyLocally(String conversationId) async {
    if (conversationId.isEmpty) return null;
    try {
      final ck = await _keyStorage.get(conversationId);
      if (ck == null || ck.key.isEmpty) return null;
      return ck.key;
    } on FormatException catch (e) {
      _log.w('EncryptionService: corrupted key for $conversationId', error: e);
      throw EncryptionServiceException(
        'Corrupted or missing key for conversation.',
        conversationId: conversationId,
        cause: e,
      );
    } catch (e, st) {
      _log.e('EncryptionService: getKeyLocally failed', error: e, stackTrace: st);
      throw EncryptionServiceException(
        'Failed to get key: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Returns true if a key exists in Hive for [conversationId].
  Future<bool> hasKey(String conversationId) async {
    if (conversationId.isEmpty) return false;
    try {
      return _keyStorage.has(conversationId);
    } catch (e, st) {
      _log.e('EncryptionService: hasKey failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Removes the key for [conversationId] from Hive.
  Future<void> deleteKey(String conversationId) async {
    if (conversationId.isEmpty) {
      throw EncryptionServiceException('conversationId must not be empty.', conversationId: conversationId);
    }
    try {
      await _keyStorage.delete(conversationId);
      _log.d('EncryptionService: deleted key for $conversationId');
    } catch (e, st) {
      _log.e('EncryptionService: deleteKey failed', error: e, stackTrace: st);
      throw EncryptionServiceException(
        'Failed to delete key: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  // --- Encryption / decryption (AES-256 CBC, PKCS7) ---

  /// Encrypts [plaintext] with [key] (base64). Generates a new IV per message.
  /// Returns [EncryptedMessage] with base64 [encryptedContent] and [iv] for Firestore.
  Future<EncryptedMessage> encryptMessage(String plaintext, String key) async {
    _validateBase64Key(key);
    try {
      final keyBytes = Uint8List.fromList(base64Decode(key));
      final ivBytes = _secureRandomBytes(_ivLengthBytes);
      final plainBytes = plaintext.isEmpty
          ? Uint8List.fromList([_emptySentinel])
          : Uint8List.fromList(utf8.encode(plaintext));
      final encryptedBytes = _aesCbcEncrypt(plainBytes, keyBytes, ivBytes);
      _log.d('EncryptionService: encrypted message (${plainBytes.length} bytes)');
      return EncryptedMessage(
        encryptedContent: base64Encode(encryptedBytes),
        iv: base64Encode(ivBytes),
      );
    } catch (e, st) {
      _log.e('EncryptionService: encryptMessage failed', error: e, stackTrace: st);
      throw EncryptionServiceException('Encryption failed', cause: e);
    }
  }

  /// Decrypts [encrypted] (base64) with [iv] (base64) and [key] (base64).
  /// Returns plaintext string.
  Future<String> decryptMessage(String encrypted, String iv, String key) async {
    _validateBase64Key(key);
    if (encrypted.isEmpty) {
      throw EncryptionServiceException('Encrypted content must not be empty.');
    }
    try {
      final keyBytes = Uint8List.fromList(base64Decode(key));
      final ivBytes = base64Decode(iv);
      if (ivBytes.length != _ivLengthBytes) {
        throw EncryptionServiceException(
          'IV must be $_ivLengthBytes bytes, got ${ivBytes.length}.',
          cause: ArgumentError('Invalid IV length'),
        );
      }
      final encryptedBytes = Uint8List.fromList(base64Decode(encrypted));
      final decryptedBytes = _aesCbcDecrypt(encryptedBytes, keyBytes, Uint8List.fromList(ivBytes));
      if (decryptedBytes.length == 1 && decryptedBytes[0] == _emptySentinel) {
        return '';
      }
      _log.d('EncryptionService: decrypted message (${decryptedBytes.length} bytes)');
      return utf8.decode(decryptedBytes);
    } on FormatException catch (e) {
      _log.w('EncryptionService: decryptMessage bad base64/corrupted', error: e);
      throw EncryptionServiceException('Corrupted or invalid encrypted data', cause: e);
    } on ArgumentError catch (e) {
      _log.w('EncryptionService: decryptMessage invalid padding/wrong key', error: e);
      throw EncryptionServiceException('Decryption failed (wrong key or corrupted data)', cause: e);
    } catch (e, st) {
      _log.e('EncryptionService: decryptMessage failed', error: e, stackTrace: st);
      throw EncryptionServiceException('Decryption failed', cause: e);
    }
  }

  Uint8List _aesCbcEncrypt(Uint8List plain, Uint8List key, Uint8List iv) {
    final blockCipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(key), iv);
    final padded = PaddedBlockCipherImpl(PKCS7Padding(), blockCipher);
    padded.init(true, PaddedBlockCipherParameters(params, null));
    return padded.process(plain);
  }

  Uint8List _aesCbcDecrypt(Uint8List encrypted, Uint8List key, Uint8List iv) {
    final blockCipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(key), iv);
    final padded = PaddedBlockCipherImpl(PKCS7Padding(), blockCipher);
    padded.init(false, PaddedBlockCipherParameters(params, null));
    return padded.process(encrypted);
  }

  // --- Key derivation (access code flow) ---

  /// Derives an AES key from [accessCode] and [salt] using PBKDF2 (10,000 iterations).
  /// Returns base64-encoded key suitable for [storeKeyLocally] or [encryptMessage].
  Future<String> deriveKeyFromCode(String accessCode, String salt) async {
    if (accessCode.isEmpty) {
      throw EncryptionServiceException('Access code must not be empty.');
    }
    try {
      final saltBytes = utf8.encode(salt);
      if (saltBytes.length < 8) {
        throw EncryptionServiceException('Salt must be at least 8 bytes.');
      }
      final saltUint = Uint8List.fromList(
        saltBytes.length >= 16 ? saltBytes.take(16).toList() : _padSalt(saltBytes),
      );
      final codeBytes = Uint8List.fromList(utf8.encode(accessCode));
      final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(saltUint, _pbkdf2Iterations, _pbkdf2KeyLength));
      final key = derivator.process(codeBytes);
      final base64Key = base64Encode(key);
      _log.d('EncryptionService: derived key from access code');
      return base64Key;
    } catch (e, st) {
      _log.e('EncryptionService: deriveKeyFromCode failed', error: e, stackTrace: st);
      if (e is EncryptionServiceException) rethrow;
      throw EncryptionServiceException('Key derivation failed', cause: e);
    }
  }

  Uint8List _padSalt(List<int> salt) {
    final out = Uint8List(16);
    for (var i = 0; i < salt.length && i < 16; i++) out[i] = salt[i];
    return out;
  }

  // --- Utility ---

  /// Generates a random 16-byte IV. Returns base64 string.
  String generateSecureIV() {
    try {
      final iv = _secureRandomBytes(_ivLengthBytes);
      return base64Encode(iv);
    } catch (e, st) {
      _log.e('EncryptionService: generateSecureIV failed', error: e, stackTrace: st);
      throw EncryptionServiceException('Failed to generate IV', cause: e);
    }
  }

  void _validateBase64Key(String key) {
    if (key.isEmpty) {
      throw EncryptionServiceException('Key must not be empty.');
    }
    try {
      final bytes = base64Decode(key);
      if (bytes.length != _aesKeyLengthBytes) {
        throw EncryptionServiceException(
          'Key must be $_aesKeyLengthBytes bytes (base64 decoded), got ${bytes.length}.',
        );
      }
    } on FormatException catch (e) {
      throw EncryptionServiceException('Invalid base64 key', cause: e);
    }
  }

  Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) bytes[i] = random.nextInt(256);
    return bytes;
  }
}
