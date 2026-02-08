import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

/// Exception thrown when a key operation fails (missing, corrupted, or storage error).
class KeyManagerException implements Exception {
  final String message;
  final String? conversationId;
  final Object? cause;

  const KeyManagerException(
    this.message, {
    this.conversationId,
    this.cause,
  });

  @override
  String toString() =>
      'KeyManagerException: $message${conversationId != null ? ' (conversationId: $conversationId)' : ''}${cause != null ? ' | cause: $cause' : ''}';
}

/// Minimal key-value storage interface used by [KeyManager].
/// Allows tests to use an in-memory implementation; production uses [FlutterSecureStorage] via [SecureStorageAdapter].
abstract interface class KeyManagerStorage {
  Future<void> write({required String key, required String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

/// Adapter so [FlutterSecureStorage] can be used as [KeyManagerStorage].
class SecureStorageAdapter implements KeyManagerStorage {
  SecureStorageAdapter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// Manages per-conversation encryption keys: generation, secure storage,
/// retrieval, and derivation using PBKDF2. Keys are stored via [KeyManagerStorage]
/// (e.g. [SecureStorageAdapter] over [FlutterSecureStorage]) indexed by conversation ID.
class KeyManager {
  KeyManager({
    KeyManagerStorage? storage,
    Logger? logger,
  })  : _storage = storage ?? SecureStorageAdapter(),
        _log = logger ?? Logger();

  final KeyManagerStorage _storage;
  final Logger _log;

  /// Storage key prefix so we don't collide with other app data.
  static const String _keyPrefix = 'anon_cast_conv_key_';
  /// Prefix for storing current key version per conversation (value: "0", "1", ...).
  static const String _currentVersionPrefix = 'anon_cast_conv_current_';

  /// AES-256 key length in bytes.
  static const int keyLengthBytes = 32;

  /// PBKDF2 iteration count (higher = slower, more secure).
  static const int pbkdf2Iterations = 100000;

  /// Salt length in bytes for key derivation.
  static const int saltLengthBytes = 16;

  /// Whether the manager has been disposed (no further operations allowed).
  bool _disposed = false;

  void _checkNotDisposed() {
    if (_disposed) {
      throw KeyManagerException('KeyManager has been disposed.');
    }
  }

  /// Generates a new random 256-bit key suitable for AES-256.
  /// Use this for a new conversation; then call [storeKey] to persist it.
  ///
  /// Returns raw key bytes (e.g. for [EncryptionUtil] or AES-256).
  /// Throws [KeyManagerException] if the manager is disposed.
  Uint8List generateKey() {
    _checkNotDisposed();
    final key = Uint8List(keyLengthBytes);
    final random = Random.secure();
    for (var i = 0; i < key.length; i++) {
      key[i] = random.nextInt(256);
    }
    _log.d('KeyManager: generated new ${key.length}-byte key');
    return key;
  }

  /// Derives a 256-bit key from [secret] and [conversationId] using PBKDF2-HMAC-SHA256.
  /// Optional [salt] can be provided; if null, a salt derived from [conversationId] is used.
  /// Use when you want a deterministic key from a user secret instead of a random key.
  ///
  /// Throws [KeyManagerException] if the manager is disposed or derivation fails.
  Uint8List deriveKey(
    List<int> secret,
    String conversationId, {
    Uint8List? salt,
  }) {
    _checkNotDisposed();
    if (conversationId.isEmpty) {
      throw KeyManagerException('conversationId must not be empty.');
    }
    final saltBytes = salt ?? _saltFromConversationId(conversationId);
    if (saltBytes.length < 8) {
      throw KeyManagerException('Salt must be at least 8 bytes.');
    }
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(saltBytes, pbkdf2Iterations, keyLengthBytes));
    final key = derivator.process(Uint8List.fromList(secret));
    _log.d('KeyManager: derived key for conversation $conversationId');
    return key;
  }

  /// Stores [key] for [conversationId] at the current version (or version 0 if first time).
  /// Overwrites the key at the current version. [key] must be [keyLengthBytes] (32) bytes.
  ///
  /// Throws [KeyManagerException] if arguments are invalid, storage fails, or manager is disposed.
  Future<void> storeKey(String conversationId, Uint8List key) async {
    _checkNotDisposed();
    final version = await getCurrentKeyVersion(conversationId) ?? 0;
    await storeKeyWithVersion(conversationId, version, key);
    await setCurrentKeyVersion(conversationId, version);
  }

  /// Stores [key] for [conversationId] at a specific [version].
  /// Used by key rotation to add a new version while keeping the old one for rollback.
  Future<void> storeKeyWithVersion(
      String conversationId, int version, Uint8List key) async {
    _checkNotDisposed();
    if (conversationId.isEmpty) {
      throw KeyManagerException('conversationId must not be empty.');
    }
    if (key.length != keyLengthBytes) {
      throw KeyManagerException(
        'Key must be $keyLengthBytes bytes, got ${key.length}.',
        conversationId: conversationId,
      );
    }
    final storageKey = _storageKeyForVersion(conversationId, version);
    try {
      final value = base64Encode(key);
      await _storage.write(key: storageKey, value: value);
      _log.d('KeyManager: stored key for $conversationId version $version');
    } catch (e, st) {
      _log.e('KeyManager: failed to store key', error: e, stackTrace: st);
      throw KeyManagerException(
        'Failed to store key: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Returns the current key version for [conversationId], or null if none set.
  Future<int?> getCurrentKeyVersion(String conversationId) async {
    _checkNotDisposed();
    if (conversationId.isEmpty) return null;
    try {
      final value =
          await _storage.read(key: '$_currentVersionPrefix$conversationId');
      if (value == null || value.isEmpty) return null;
      return int.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  /// Sets the current key version for [conversationId]. Used after rotation.
  Future<void> setCurrentKeyVersion(
      String conversationId, int version) async {
    _checkNotDisposed();
    if (conversationId.isEmpty) {
      throw KeyManagerException('conversationId must not be empty.');
    }
    try {
      await _storage.write(
          key: '$_currentVersionPrefix$conversationId', value: version.toString());
    } catch (e, st) {
      _log.e('KeyManager: failed to set current version', error: e, stackTrace: st);
      throw KeyManagerException(
        'Failed to set current key version: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Retrieves the key at a specific [version] for [conversationId], or null if not found.
  Future<Uint8List?> retrieveKeyWithVersion(
      String conversationId, int version) async {
    _checkNotDisposed();
    if (conversationId.isEmpty) return null;
    final storageKey = _storageKeyForVersion(conversationId, version);
    try {
      final value = await _storage.read(key: storageKey);
      if (value == null || value.isEmpty) return null;
      final key = Uint8List.fromList(base64Decode(value));
      if (key.length != keyLengthBytes) {
        throw KeyManagerException(
          'Stored key has invalid length ${key.length}, expected $keyLengthBytes.',
          conversationId: conversationId,
        );
      }
      return key;
    } on FormatException catch (e) {
      _log.w('KeyManager: corrupted key data for $conversationId v$version',
          error: e);
      throw KeyManagerException(
        'Corrupted key data for conversation.',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Retrieves the current key for [conversationId] (at current version), or null if not found.
  /// Throws [KeyManagerException] if the stored value is corrupted (e.g. invalid base64)
  /// or if the manager is disposed.
  Future<Uint8List?> retrieveKey(String conversationId) async {
    _checkNotDisposed();
    if (conversationId.isEmpty) {
      throw KeyManagerException('conversationId must not be empty.');
    }
    final version = await getCurrentKeyVersion(conversationId);
    if (version == null) {
      return _retrieveKeyLegacy(conversationId);
    }
    return retrieveKeyWithVersion(conversationId, version);
  }

  /// Legacy single-key storage (no version suffix). Used for backward compatibility.
  Future<Uint8List?> _retrieveKeyLegacy(String conversationId) async {
    final storageKey = _storageKey(conversationId);
    try {
      final value = await _storage.read(key: storageKey);
      if (value == null || value.isEmpty) {
        _log.d('KeyManager: no key found for conversation $conversationId');
        return null;
      }
      final key = Uint8List.fromList(base64Decode(value));
      if (key.length != keyLengthBytes) {
        throw KeyManagerException(
          'Stored key has invalid length ${key.length}, expected $keyLengthBytes.',
          conversationId: conversationId,
        );
      }
      return key;
    } on FormatException catch (e) {
      _log.w('KeyManager: corrupted key data for $conversationId', error: e);
      throw KeyManagerException(
        'Corrupted key data for conversation.',
        conversationId: conversationId,
        cause: e,
      );
    } on KeyManagerException {
      rethrow;
    } catch (e, st) {
      _log.e('KeyManager: failed to retrieve key', error: e, stackTrace: st);
      throw KeyManagerException(
        'Failed to retrieve key: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Retrieves the key for [conversationId] or throws if missing/corrupted.
  /// Use when a key is required for decryption; use [retrieveKey] when absence is acceptable.
  Future<Uint8List> getKeyOrThrow(String conversationId) async {
    final key = await retrieveKey(conversationId);
    if (key == null) {
      throw KeyManagerException(
        'No key found for conversation.',
        conversationId: conversationId,
      );
    }
    return key;
  }

  /// Deletes the current key and version metadata for [conversationId].
  /// Does not delete other versions (e.g. old keys kept for rollback).
  Future<void> deleteKey(String conversationId) async {
    _checkNotDisposed();
    if (conversationId.isEmpty) {
      throw KeyManagerException('conversationId must not be empty.');
    }
    final version = await getCurrentKeyVersion(conversationId);
    try {
      if (version != null) {
        await _storage.delete(
            key: _storageKeyForVersion(conversationId, version));
        await _storage.delete(key: '$_currentVersionPrefix$conversationId');
      } else {
        await _storage.delete(key: _storageKey(conversationId));
      }
      _log.d('KeyManager: deleted key for conversation $conversationId');
    } catch (e, st) {
      _log.e('KeyManager: failed to delete key', error: e, stackTrace: st);
      throw KeyManagerException(
        'Failed to delete key: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Deletes a specific key [version] for [conversationId]. Use for cleanup of old versions.
  Future<void> deleteKeyVersion(String conversationId, int version) async {
    _checkNotDisposed();
    if (conversationId.isEmpty) {
      throw KeyManagerException('conversationId must not be empty.');
    }
    try {
      await _storage.delete(
          key: _storageKeyForVersion(conversationId, version));
      _log.d('KeyManager: deleted key version $version for $conversationId');
    } catch (e, st) {
      _log.e('KeyManager: failed to delete key version', error: e, stackTrace: st);
      throw KeyManagerException(
        'Failed to delete key version: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Optional initialization (e.g. ensure storage is ready).
  /// Current implementation is a no-op; override or extend if needed.
  Future<void> init() async {
    _checkNotDisposed();
    _log.d('KeyManager: init');
  }

  /// Marks the manager as disposed. After calling [dispose], all methods
  /// will throw [KeyManagerException]. Safe to call multiple times.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _log.d('KeyManager: disposed');
  }

  String _storageKey(String conversationId) => '$_keyPrefix$conversationId';

  /// Key storage with version: v0 uses legacy key (no suffix) for backward compat.
  String _storageKeyForVersion(String conversationId, int version) {
    if (version == 0) return '$_keyPrefix$conversationId';
    return '$_keyPrefix${conversationId}_v$version';
  }

  /// Produces a [saltLengthBytes]-byte salt from [conversationId] (padded or hashed so length >= 8).
  Uint8List _saltFromConversationId(String conversationId) {
    final bytes = utf8.encode(conversationId);
    if (bytes.length >= saltLengthBytes) {
      return Uint8List.fromList(bytes.take(saltLengthBytes).toList());
    }
    final out = Uint8List(saltLengthBytes);
    for (var i = 0; i < bytes.length; i++) out[i] = bytes[i];
    return out;
  }
}
