import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

import 'encryption_service.dart';
import 'local_storage_service.dart';

// =============================================================================
// KEY BACKUP STRATEGY (for future multi-device support)
// =============================================================================
//
// Current limitation: Encryption keys are stored locally only (Hive). On a new
// device the admin cannot decrypt existing conversations.
//
// Future options (architecture ready; implementation can be added later):
//
// Option A: User-controlled password-encrypted backup
//   - Admin exports keys to an encrypted file (this implementation).
//   - Transfer file manually (email, USB, cloud drive) → import on new device.
//   - Same password decrypts and restores keys to Hive.
//
// Option B: Device-to-device key transfer (QR code)
//   - Encode encrypted key bundle in QR(s); scan on new device.
//   - Short-lived, no persistent backup; good for "pair this device" flow.
//
// Option C: Secure cloud backup with user's master password
//   - Encrypted blob stored in Firestore/backend; decrypt with master password.
//   - Requires backend schema and secure channel; out of scope for MVP.
//
// MVP: Admin may lose access if they switch devices without exporting/importing
// keys. Acceptable for single-device (e.g. school admin tablet).
// =============================================================================

/// Thrown when key export/import or sync checks fail.
class SyncServiceException implements Exception {
  const SyncServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'SyncServiceException: $message${cause != null ? ' | cause: $cause' : ''}';
}

/// Format version for the encrypted key backup blob.
const int _exportFormatVersion = 1;

/// Salt and IV length in bytes.
const int _saltLength = 16;
const int _ivLength = 16;
const int _pbkdf2Iterations = 100000;
const int _pbkdf2KeyLength = 32;

/// Foundation for multi-device key sync. Exports conversation keys to a
/// password-encrypted blob and imports them on another device so the admin
/// can decrypt conversations there.
///
/// UI flow (basic):
/// - Settings: "Export Conversation Keys" → user enters password → file downloads.
/// - New device: "Import Conversation Keys" → upload file → enter password →
///   keys restored to Hive; all conversations decryptable.
class SyncService {
  SyncService({
    LocalStorageService? storage,
    EncryptionService? encryption,
    Logger? logger,
  })  : _storage = storage ?? LocalStorageService.instance,
        _encryption = encryption ?? EncryptionService(),
        _log = logger ?? Logger();

  final LocalStorageService _storage;
  final EncryptionService _encryption;
  final Logger _log;

  /// Checks which conversations the user cannot decrypt (no local key).
  /// [conversationIds]: list of conversation IDs the user has access to (e.g. from Firestore).
  /// Returns the subset for which there is no key in Hive.
  /// Future: add getInaccessibleConversations(String userId) when we have user→conversations.
  Future<List<String>> getInaccessibleConversations(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return [];
    try {
      await _storage.init();
      final inaccessible = <String>[];
      for (final id in conversationIds) {
        final key = await _storage.getConversationKey(id);
        if (key == null || key.isEmpty) {
          inaccessible.add(id);
        }
      }
      _log.d('SyncService: ${inaccessible.length} inaccessible of ${conversationIds.length}');
      return inaccessible;
    } catch (e, st) {
      _log.e('SyncService: getInaccessibleConversations failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Returns true if the user needs to sync keys (has conversations they can't decrypt).
  /// When [conversationIds] is provided (e.g. from Firestore), returns true if any lack a local key.
  /// When [conversationIds] is null/empty, returns false (no way to know without conversation list).
  /// Future: add userId-based overload when we have a user→conversations API.
  Future<bool> needsKeySync([List<String>? conversationIds]) async {
    if (conversationIds == null || conversationIds.isEmpty) return false;
    final list = await getInaccessibleConversations(conversationIds);
    return list.isNotEmpty;
  }

  /// Exports all conversation keys to a password-encrypted string (base64).
  /// User can save this to a file and transfer to another device.
  /// Encryption: PBKDF2 (password + salt) → AES-256-CBC; format: version + salt + iv + ciphertext.
  Future<String> exportEncryptedKeys(String userPassword) async {
    if (userPassword.isEmpty) {
      throw SyncServiceException('Password must not be empty.');
    }
    try {
      await _storage.init();
      final keys = await _storage.getAllConversationKeys();
      if (keys.isEmpty) {
        throw SyncServiceException('No conversation keys to export.');
      }
      final payload = jsonEncode(keys);
      final salt = _secureRandomBytes(_saltLength);
      final iv = _secureRandomBytes(_ivLength);
      final keyBytes = _deriveKey(userPassword, salt);
      final plainBytes = Uint8List.fromList(utf8.encode(payload));
      final ciphertext = _aesCbcEncrypt(plainBytes, keyBytes, iv);
      final blob = Uint8List(1 + _saltLength + _ivLength + ciphertext.length);
      blob[0] = _exportFormatVersion;
      blob.setRange(1, 1 + _saltLength, salt);
      blob.setRange(1 + _saltLength, 1 + _saltLength + _ivLength, iv);
      blob.setRange(1 + _saltLength + _ivLength, blob.length, ciphertext);
      _log.d('SyncService: exported ${keys.length} keys');
      return base64Encode(blob);
    } on SyncServiceException {
      rethrow;
    } catch (e, st) {
      _log.e('SyncService: exportEncryptedKeys failed', error: e, stackTrace: st);
      throw SyncServiceException('Export failed', cause: e);
    }
  }

  /// Imports conversation keys from a password-encrypted string (base64 from export).
  /// Restores each key to Hive and to [EncryptionService] so messages can be decrypted.
  /// Returns the number of keys imported.
  Future<int> importEncryptedKeys(String encryptedData, String userPassword) async {
    if (encryptedData.isEmpty) {
      throw SyncServiceException('Encrypted data must not be empty.');
    }
    if (userPassword.isEmpty) {
      throw SyncServiceException('Password must not be empty.');
    }
    try {
      final blob = base64Decode(encryptedData);
      if (blob.length < 1 + _saltLength + _ivLength + 1) {
        throw SyncServiceException('Invalid or corrupted backup data.');
      }
      final version = blob[0];
      if (version != _exportFormatVersion) {
        throw SyncServiceException('Unsupported backup format version: $version');
      }
      final salt = Uint8List.sublistView(blob, 1, 1 + _saltLength);
      final iv = Uint8List.sublistView(blob, 1 + _saltLength, 1 + _saltLength + _ivLength);
      final ciphertext = Uint8List.sublistView(
        blob,
        1 + _saltLength + _ivLength,
        blob.length,
      );
      final keyBytes = _deriveKey(userPassword, salt);
      final plainBytes = _aesCbcDecrypt(ciphertext, keyBytes, iv);
      final payload = utf8.decode(plainBytes);
      final keys = jsonDecode(payload) as Map<String, dynamic>;
      await _storage.init();
      int count = 0;
      for (final entry in keys.entries) {
        final conversationId = entry.key;
        final key = entry.value as String?;
        if (conversationId.isEmpty || key == null || key.isEmpty) continue;
        await _storage.storeConversationKey(conversationId, key);
        await _encryption.storeKeyLocally(conversationId, key);
        count++;
      }
      _log.d('SyncService: imported $count keys');
      return count;
    } on FormatException catch (e) {
      _log.w('SyncService: importEncryptedKeys bad base64/JSON or wrong password', error: e);
      throw SyncServiceException('Invalid backup or wrong password.', cause: e);
    } on SyncServiceException {
      rethrow;
    } catch (e, st) {
      _log.e('SyncService: importEncryptedKeys failed', error: e, stackTrace: st);
      throw SyncServiceException('Import failed', cause: e);
    }
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _pbkdf2KeyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
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
}
