import 'dart:convert';

import 'package:anon_cast/services/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/in_memory_key_storage.dart';

void main() {
  late EncryptionService service;
  late InMemoryConversationKeyStorage storage;

  setUp(() {
    storage = InMemoryConversationKeyStorage();
    service = EncryptionService(keyStorage: storage);
  });

  group('EncryptionService', () {
    group('generateConversationKey', () {
      test('returns base64 string of 32-byte key', () async {
        final key = await service.generateConversationKey();
        expect(key, isNotEmpty);
        final decoded = base64Decode(key);
        expect(decoded.length, 32);
      });

      test('returns different key each time', () async {
        final key1 = await service.generateConversationKey();
        final key2 = await service.generateConversationKey();
        expect(key1, isNot(equals(key2)));
      });
    });

    group('storeKeyLocally / getKeyLocally / hasKey / deleteKey', () {
      test('store and get round-trip', () async {
        const cid = 'conv-1';
        final key = await service.generateConversationKey();
        await service.storeKeyLocally(cid, key);
        expect(await service.hasKey(cid), isTrue);
        final retrieved = await service.getKeyLocally(cid);
        expect(retrieved, key);
      });

      test('getKeyLocally returns null when no key', () async {
        expect(await service.getKeyLocally('nonexistent'), isNull);
        expect(await service.hasKey('nonexistent'), isFalse);
      });

      test('deleteKey removes key', () async {
        const cid = 'conv-2';
        final key = await service.generateConversationKey();
        await service.storeKeyLocally(cid, key);
        expect(await service.hasKey(cid), isTrue);
        await service.deleteKey(cid);
        expect(await service.hasKey(cid), isFalse);
        expect(await service.getKeyLocally(cid), isNull);
      });

      test('storeKeyLocally throws for empty conversationId', () async {
        final key = await service.generateConversationKey();
        expect(
          () => service.storeKeyLocally('', key),
          throwsA(isA<EncryptionServiceException>()),
        );
      });

      test('deleteKey throws for empty conversationId', () async {
        expect(
          () => service.deleteKey(''),
          throwsA(isA<EncryptionServiceException>()),
        );
      });
    });

    group('encryptMessage / decryptMessage', () {
      test('round-trip encrypt and decrypt', () async {
        final key = await service.generateConversationKey();
        const plaintext = 'Hello, zero-knowledge world!';
        final encrypted = await service.encryptMessage(plaintext, key);
        expect(encrypted.encryptedContent, isNotEmpty);
        expect(encrypted.iv, isNotEmpty);
        final decrypted = await service.decryptMessage(
          encrypted.encryptedContent,
          encrypted.iv,
          key,
        );
        expect(decrypted, plaintext);
      });

      test('same plaintext produces different ciphertext (IV differs)', () async {
        final key = await service.generateConversationKey();
        const plaintext = 'Same text';
        final enc1 = await service.encryptMessage(plaintext, key);
        final enc2 = await service.encryptMessage(plaintext, key);
        expect(enc1.encryptedContent, isNot(equals(enc2.encryptedContent)));
        expect(enc1.iv, isNot(equals(enc2.iv)));
        expect(await service.decryptMessage(enc1.encryptedContent, enc1.iv, key), plaintext);
        expect(await service.decryptMessage(enc2.encryptedContent, enc2.iv, key), plaintext);
      });

      test('empty string round-trip', () async {
        final key = await service.generateConversationKey();
        final encrypted = await service.encryptMessage('', key);
        final decrypted = await service.decryptMessage(
          encrypted.encryptedContent,
          encrypted.iv,
          key,
        );
        expect(decrypted, '');
      });

      test('decryptMessage throws on wrong key', () async {
        final key1 = await service.generateConversationKey();
        final key2 = await service.generateConversationKey();
        final encrypted = await service.encryptMessage('secret', key1);
        expect(
          () => service.decryptMessage(encrypted.encryptedContent, encrypted.iv, key2),
          throwsA(isA<EncryptionServiceException>()),
        );
      });

      test('decryptMessage throws on empty encrypted', () async {
        final key = await service.generateConversationKey();
        expect(
          () => service.decryptMessage('', base64Encode(List.filled(16, 0)), key),
          throwsA(isA<EncryptionServiceException>()),
        );
      });
    });

    group('deriveKeyFromCode', () {
      test('derives deterministic key from code and salt', () async {
        const code = 'my-access-code';
        const salt = 'my-salt-at-least-8-chars';
        final key1 = await service.deriveKeyFromCode(code, salt);
        final key2 = await service.deriveKeyFromCode(code, salt);
        expect(key1, key2);
        expect(base64Decode(key1).length, 32);
      });

      test('different salt produces different key', () async {
        const code = 'same-code';
        final key1 = await service.deriveKeyFromCode(code, 'salt1--------');
        final key2 = await service.deriveKeyFromCode(code, 'salt2--------');
        expect(key1, isNot(equals(key2)));
      });

      test('derived key can encrypt and decrypt', () async {
        const code = 'secret-code';
        const salt = 'long-enough-salt-16';
        final key = await service.deriveKeyFromCode(code, salt);
        const plaintext = 'Message with derived key';
        final encrypted = await service.encryptMessage(plaintext, key);
        final decrypted = await service.decryptMessage(
          encrypted.encryptedContent,
          encrypted.iv,
          key,
        );
        expect(decrypted, plaintext);
      });

      test('throws for empty access code', () async {
        expect(
          () => service.deriveKeyFromCode('', 'salt12345'),
          throwsA(isA<EncryptionServiceException>()),
        );
      });
    });

    group('generateSecureIV', () {
      test('returns base64 string of 16 bytes', () {
        final iv = service.generateSecureIV();
        expect(iv, isNotEmpty);
        expect(base64Decode(iv).length, 16);
      });

      test('returns different IV each time', () {
        final iv1 = service.generateSecureIV();
        final iv2 = service.generateSecureIV();
        expect(iv1, isNot(equals(iv2)));
      });
    });
  });
}
