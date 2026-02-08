import 'dart:convert';
import 'dart:typed_data';

import 'package:anon_cast/services/key_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory implementation of [KeyManagerStorage] for tests.
class InMemoryKeyManagerStorage implements KeyManagerStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

void main() {
  late KeyManager keyManager;
  late InMemoryKeyManagerStorage storage;

  setUp(() {
    storage = InMemoryKeyManagerStorage();
    keyManager = KeyManager(storage: storage);
  });

  tearDown(() {
    keyManager.dispose();
  });

  group('KeyManager', () {
    group('generateKey', () {
      test('returns 32-byte key', () {
        final key = keyManager.generateKey();
        expect(key.length, KeyManager.keyLengthBytes);
        expect(key, isA<Uint8List>());
      });

      test('returns different key each time', () {
        final key1 = keyManager.generateKey();
        final key2 = keyManager.generateKey();
        expect(key1, isNot(equals(key2)));
      });

      test('throws after dispose', () {
        keyManager.dispose();
        expect(() => keyManager.generateKey(), throwsA(isA<KeyManagerException>()));
      });
    });

    group('deriveKey', () {
      test('derives 32-byte key from secret and conversationId', () {
        final key = keyManager.deriveKey(
          utf8.encode('user-secret'),
          'conv-123',
        );
        expect(key.length, KeyManager.keyLengthBytes);
      });

      test('same inputs produce same key', () {
        final secret = utf8.encode('secret');
        final key1 = keyManager.deriveKey(secret, 'conv-1');
        final key2 = keyManager.deriveKey(secret, 'conv-1');
        expect(key1, equals(key2));
      });

      test('different conversationId produces different key', () {
        final secret = utf8.encode('secret');
        final key1 = keyManager.deriveKey(secret, 'conv-1');
        final key2 = keyManager.deriveKey(secret, 'conv-2');
        expect(key1, isNot(equals(key2)));
      });

      test('throws for empty conversationId', () {
        expect(
          () => keyManager.deriveKey([1, 2, 3], ''),
          throwsA(isA<KeyManagerException>()),
        );
      });

      test('throws after dispose', () {
        keyManager.dispose();
        expect(
          () => keyManager.deriveKey([1, 2, 3], 'conv-1'),
          throwsA(isA<KeyManagerException>()),
        );
      });
    });

    group('storeKey and retrieveKey', () {
      test('stores and retrieves key by conversationId', () async {
        final convId = 'conv-store-retrieve';
        final key = keyManager.generateKey();
        await keyManager.storeKey(convId, key);
        final retrieved = await keyManager.retrieveKey(convId);
        expect(retrieved, isNotNull);
        expect(retrieved, equals(key));
      });

      test('retrieveKey returns null when no key stored', () async {
        final result = await keyManager.retrieveKey('nonexistent');
        expect(result, isNull);
      });

      test('storeKey overwrites existing key', () async {
        final convId = 'conv-overwrite';
        final key1 = keyManager.generateKey();
        final key2 = keyManager.generateKey();
        await keyManager.storeKey(convId, key1);
        await keyManager.storeKey(convId, key2);
        final retrieved = await keyManager.retrieveKey(convId);
        expect(retrieved, equals(key2));
      });

      test('storeKey throws for empty conversationId', () async {
        final key = keyManager.generateKey();
        expect(
          keyManager.storeKey('', key),
          throwsA(isA<KeyManagerException>()),
        );
      });

      test('storeKey throws for wrong key length', () async {
        final shortKey = Uint8List(16);
        expect(
          keyManager.storeKey('conv-1', shortKey),
          throwsA(isA<KeyManagerException>()),
        );
      });

      test('retrieveKey throws for empty conversationId', () async {
        expect(
          keyManager.retrieveKey(''),
          throwsA(isA<KeyManagerException>()),
        );
      });

      test('throws after dispose', () async {
        final key = keyManager.generateKey();
        keyManager.dispose();
        await expectLater(
          keyManager.storeKey('conv-1', key),
          throwsA(isA<KeyManagerException>()),
        );
        await expectLater(
          keyManager.retrieveKey('conv-1'),
          throwsA(isA<KeyManagerException>()),
        );
      });
    });

    group('getKeyOrThrow', () {
      test('returns key when present', () async {
        final convId = 'conv-get-throw';
        final key = keyManager.generateKey();
        await keyManager.storeKey(convId, key);
        final retrieved = await keyManager.getKeyOrThrow(convId);
        expect(retrieved, equals(key));
      });

      test('throws when key missing', () async {
        expect(
          keyManager.getKeyOrThrow('missing'),
          throwsA(isA<KeyManagerException>()),
        );
      });
    });

    group('deleteKey', () {
      test('removes stored key', () async {
        final convId = 'conv-delete';
        final key = keyManager.generateKey();
        await keyManager.storeKey(convId, key);
        expect(await keyManager.retrieveKey(convId), isNotNull);
        await keyManager.deleteKey(convId);
        expect(await keyManager.retrieveKey(convId), isNull);
      });

      test('succeeds when no key exists (no-op)', () async {
        await keyManager.deleteKey('nonexistent');
      });

      test('throws for empty conversationId', () async {
        expect(
          keyManager.deleteKey(''),
          throwsA(isA<KeyManagerException>()),
        );
      });

      test('throws after dispose', () async {
        keyManager.dispose();
        expect(
          keyManager.deleteKey('conv-1'),
          throwsA(isA<KeyManagerException>()),
        );
      });
    });

    group('init', () {
      test('completes without error', () async {
        await keyManager.init();
      });

      test('throws after dispose', () async {
        keyManager.dispose();
        await expectLater(keyManager.init(), throwsA(isA<KeyManagerException>()));
      });
    });

    group('dispose', () {
      test('is safe to call multiple times', () {
        keyManager.dispose();
        keyManager.dispose();
      });
    });

    group('corrupted key handling', () {
      test('retrieveKey throws KeyManagerException for invalid base64', () async {
        // Write non-base64 value directly via storage
        await storage.write(
          key: 'anon_cast_conv_key_corrupted',
          value: 'not-valid-base64!!!',
        );
        try {
          await keyManager.retrieveKey('corrupted');
          fail('expected KeyManagerException');
        } on KeyManagerException catch (e) {
          expect(e.conversationId, 'corrupted');
          expect(e.message, contains('Corrupted'));
        }
      });
    });

    group('KeyManagerException', () {
      test('toString includes message and conversationId', () {
        const e = KeyManagerException('test message', conversationId: 'conv-1');
        expect(e.toString(), contains('test message'));
        expect(e.toString(), contains('conv-1'));
      });
    });
  });
}
