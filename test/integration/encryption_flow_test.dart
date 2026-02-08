import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:anon_cast/services/key_manager.dart';
import 'package:anon_cast/utils/encryption_util.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/encryption_test_helpers.dart';
import '../helpers/mock_firestore.dart';
import '../helpers/mock_storage.dart';

/// Simulates the app flow: encrypt before Firestore write, decrypt after read.
/// Uses KeyManager for keys and EncryptionUtil for AES-256.
class EncryptedMessageFlow {
  EncryptedMessageFlow({
    required KeyManager keyManager,
    required MockFirestoreMessages firestore,
    Uint8List Function()? ivGenerator,
  })  : _keyManager = keyManager,
        _firestore = firestore,
        _ivGenerator = ivGenerator ?? _defaultIvGenerator;

  final KeyManager _keyManager;
  final MockFirestoreMessages _firestore;
  final Uint8List Function() _ivGenerator;

  static Uint8List _defaultIvGenerator() =>
      EncryptionUtil.generateRandomBytes(16);

  /// Test-friendly IV generator (avoids pointycastle SecureRandom in test env).
  static Uint8List testIvGenerator() {
    final b = Uint8List(16);
    final r = Random.secure();
    for (var i = 0; i < 16; i++) {
      b[i] = r.nextInt(256);
    }
    return b;
  }

  /// Encrypts [plaintext] with the conversation key and writes to mock Firestore.
  /// Ensures a key exists for [conversationId] (generates if missing).
  Future<Map<String, dynamic>> writeMessage(
    String conversationId,
    String senderId,
    String plaintext,
  ) async {
    var key = await _keyManager.retrieveKey(conversationId);
    if (key == null) {
      key = _keyManager.generateKey();
      await _keyManager.storeKey(conversationId, key);
    }
    final iv = _ivGenerator();
    final encrypted = EncryptionUtil.encryptWithKeyBytes(plaintext, key, iv);
    final message = {
      'id': 'msg-${DateTime.now().millisecondsSinceEpoch}',
      'senderId': senderId,
      'encryptedContent': encrypted,
      'timestamp': DateTime.now().toIso8601String(),
      'iv': iv.toList(),
    };
    await _firestore.setMessage(conversationId, message);
    return message;
  }

  /// Reads a message from mock Firestore and decrypts with the conversation key.
  /// Throws if key is missing or decryption fails.
  Future<String> readMessage(String conversationId, int messageIndex) async {
    final raw = _firestore.getMessage(conversationId, messageIndex);
    if (raw == null) throw Exception('Message not found');
    final key = await _keyManager.getKeyOrThrow(conversationId);
    final iv = raw['iv'] as List<dynamic>?;
    if (iv == null || iv.length != 16) {
      throw Exception('Missing or invalid IV');
    }
    final ivBytes = Uint8List.fromList(iv.cast<int>());
    return EncryptionUtil.decryptWithKeyBytes(
      raw['encryptedContent'] as String,
      key,
      ivBytes,
    );
  }

  /// Returns raw stored message (encrypted content) for integrity/tampering tests.
  Map<String, dynamic>? getRawMessage(String conversationId, int index) {
    return _firestore.getMessage(conversationId, index);
  }
}

void main() {
  late KeyManager keyManager;
  late InMemoryKeyManagerStorage keyStorage;
  late MockFirestoreMessages mockFirestore;
  late EncryptedMessageFlow flow;

  setUp(() {
    keyStorage = InMemoryKeyManagerStorage();
    keyManager = KeyManager(storage: keyStorage);
    mockFirestore = MockFirestoreMessages();
    flow = EncryptedMessageFlow(
      keyManager: keyManager,
      firestore: mockFirestore,
      ivGenerator: EncryptedMessageFlow.testIvGenerator,
    );
  });

  tearDown(() {
    keyManager.dispose();
    keyStorage.clear();
    mockFirestore.clear();
  });

  group('Encryption flow integration', () {
    group('1. Message encryption before Firestore write', () {
      test('plaintext is encrypted and stored as base64 ciphertext', () async {
        const conversationId = 'conv-enc-1';
        const senderId = 'anon-user-1';
        const plaintext = EncryptionTestData.shortText;

        await flow.writeMessage(conversationId, senderId, plaintext);
        final messages = mockFirestore.getMessages(conversationId);
        expect(messages.length, 1);

        final stored = messages.first;
        final ciphertext = stored['encryptedContent'] as String;
        EncryptionAssertions.expectValidCiphertext(plaintext, ciphertext);
        EncryptionAssertions.expectBase64(ciphertext);
        EncryptionAssertions.expectValidIv(stored['iv'] as List<int>?);
      });

      test('stored content is not equal to plaintext (confidentiality)', () async {
        const conversationId = 'conv-conf';
        const plaintext = 'Secret message';

        await flow.writeMessage(conversationId, 'user1', plaintext);
        final stored = mockFirestore.getMessages(conversationId).first;
        expect(stored['encryptedContent'], isNot(equals(plaintext)));
      });

      test('different messages produce different ciphertexts (IV uniqueness)', () async {
        const conversationId = 'conv-iv';
        const plaintext = 'Same text';

        await flow.writeMessage(conversationId, 'u1', plaintext);
        await flow.writeMessage(conversationId, 'u1', plaintext);
        final messages = mockFirestore.getMessages(conversationId);
        expect(messages.length, 2);
        EncryptionAssertions.expectCiphertextsDifferent(
          messages[0]['encryptedContent'] as String,
          messages[1]['encryptedContent'] as String,
        );
      });

      for (final entry in EncryptionTestData.allCases) {
        test('encrypts ${entry.key} correctly', () async {
          const cid = 'conv-variants';
          await flow.writeMessage(cid, 'u1', entry.value);
          final list = mockFirestore.getMessages(cid);
          expect(list.length, 1);
          expect(list.first['encryptedContent'], isNotEmpty);
          EncryptionAssertions.expectValidIv(list.first['iv'] as List<int>?);
        });
      }
    });

    group('2. Message decryption after Firestore read', () {
      test('decrypted content matches original plaintext', () async {
        const conversationId = 'conv-dec-1';
        const plaintext = 'Hello, this should round-trip.';

        await flow.writeMessage(conversationId, 'anon-1', plaintext);
        final decrypted = await flow.readMessage(conversationId, 0);
        EncryptionAssertions.expectDecryptedEquals(plaintext, decrypted);
      });

      test('long message round-trips correctly', () async {
        const conversationId = 'conv-long';
        final plaintext = EncryptionTestData.longText;

        await flow.writeMessage(conversationId, 'u1', plaintext);
        final decrypted = await flow.readMessage(conversationId, 0);
        EncryptionAssertions.expectDecryptedEquals(plaintext, decrypted);
      });

      test('special characters and Unicode round-trip', () async {
        const conversationId = 'conv-unicode';
        const plaintext = EncryptionTestData.specialChars;

        await flow.writeMessage(conversationId, 'u1', plaintext);
        final decrypted = await flow.readMessage(conversationId, 0);
        EncryptionAssertions.expectDecryptedEquals(plaintext, decrypted);
      });

      test('empty message round-trips', () async {
        const conversationId = 'conv-empty';
        const plaintext = EncryptionTestData.emptyText;

        await flow.writeMessage(conversationId, 'u1', plaintext);
        final decrypted = await flow.readMessage(conversationId, 0);
        expect(decrypted, equals(plaintext));
      });
    });

    group('3. Key not found scenarios', () {
      test('readMessage throws when conversation has no key', () async {
        const conversationId = 'conv-no-key';
        await flow.writeMessage(conversationId, 'u1', 'Hi');
        await keyManager.deleteKey(conversationId);

        expect(
          () => flow.readMessage(conversationId, 0),
          throwsA(isA<KeyManagerException>()),
        );
      });

      test('writeMessage generates and stores key for new conversation', () async {
        const conversationId = 'conv-new';
        expect(await keyManager.retrieveKey(conversationId), isNull);

        await flow.writeMessage(conversationId, 'u1', 'First message');
        expect(await keyManager.retrieveKey(conversationId), isNotNull);
      });
    });

    group('4. Corrupted ciphertext handling', () {
      test('tampered ciphertext throws on decryption', () async {
        const conversationId = 'conv-tamper';
        await flow.writeMessage(conversationId, 'u1', 'Original');

        final raw = flow.getRawMessage(conversationId, 0);
        expect(raw, isNotNull);
        raw!['encryptedContent'] = base64Encode([1, 2, 3, 4, 5]);
        mockFirestore.clear();
        await mockFirestore.setMessage(conversationId, raw);

        expect(
          () => flow.readMessage(conversationId, 0),
          throwsA(anything),
        );
      });

      test('invalid base64 ciphertext throws FormatException or decrypt error', () async {
        const conversationId = 'conv-bad-b64';
        await flow.writeMessage(conversationId, 'u1', 'Ok');
        final raw = flow.getRawMessage(conversationId, 0)!;
        raw['encryptedContent'] = 'not-valid-base64!!!';
        mockFirestore.clear();
        await mockFirestore.setMessage(conversationId, raw);

        expect(
          () => flow.readMessage(conversationId, 0),
          throwsA(anything),
        );
      });

      test('missing IV throws', () async {
        const conversationId = 'conv-no-iv';
        await flow.writeMessage(conversationId, 'u1', 'Ok');
        final raw = flow.getRawMessage(conversationId, 0)!;
        raw.remove('iv');
        mockFirestore.clear();
        await mockFirestore.setMessage(conversationId, raw);

        expect(
          () => flow.readMessage(conversationId, 0),
          throwsA(anything),
        );
      });
    });

    group('5. Multiple concurrent conversations', () {
      test('each conversation uses its own key', () async {
        const c1 = 'conv-a';
        const c2 = 'conv-b';
        const plain = 'Same content';

        await flow.writeMessage(c1, 'u1', plain);
        await flow.writeMessage(c2, 'u1', plain);

        final key1 = await keyManager.getKeyOrThrow(c1);
        final key2 = await keyManager.getKeyOrThrow(c2);
        expect(key1, isNot(equals(key2)));

        final msg1 = mockFirestore.getMessages(c1).first['encryptedContent'] as String;
        final msg2 = mockFirestore.getMessages(c2).first['encryptedContent'] as String;
        expect(msg1, isNot(equals(msg2)));
      });

      test('decrypting with wrong conversation fails or yields garbage', () async {
        const c1 = 'conv-x';
        const c2 = 'conv-y';
        await flow.writeMessage(c1, 'u1', 'Secret for X');
        await flow.writeMessage(c2, 'u1', 'Secret for Y');

        final rawFromC1 = mockFirestore.getMessages(c1).first;
        await keyManager.deleteKey(c1);
        await mockFirestore.setMessage(c1, rawFromC1);

        final keyY = await keyManager.getKeyOrThrow(c2);
        final iv = Uint8List.fromList((rawFromC1['iv'] as List).cast<int>());
        final cipher = rawFromC1['encryptedContent'] as String;
        String decrypted;
        try {
          decrypted = EncryptionUtil.decryptWithKeyBytes(cipher, keyY, iv);
        } catch (_) {
          return;
        }
        expect(decrypted, isNot(equals('Secret for X')));
      });

      test('multiple messages per conversation all decrypt correctly', () async {
        const cid = 'conv-multi';
        final texts = ['First', 'Second', 'Third', EncryptionTestData.specialChars];

        for (final t in texts) {
          await flow.writeMessage(cid, 'u1', t);
        }
        for (var i = 0; i < texts.length; i++) {
          final dec = await flow.readMessage(cid, i);
          expect(dec, equals(texts[i]));
        }
      });
    });

    group('6. Message integrity verification', () {
      test('round-trip preserves exact content (no truncation or modification)', () async {
        const cid = 'conv-integrity';
        const plain = 'Exact content 123 \n\t\r';

        await flow.writeMessage(cid, 'u1', plain);
        final dec = await flow.readMessage(cid, 0);
        expect(dec, equals(plain));
        expect(dec.length, equals(plain.length));
      });

      test('single bit change in ciphertext yields invalid decryption', () async {
        const cid = 'conv-bit';
        await flow.writeMessage(cid, 'u1', 'Sensitive');
        final raw = flow.getRawMessage(cid, 0)!;
        final bytes = base64Decode(raw['encryptedContent'] as String);
        bytes[0] ^= 0x01;
        raw['encryptedContent'] = base64Encode(bytes);
        mockFirestore.clear();
        await mockFirestore.setMessage(cid, raw);

        expect(
          () => flow.readMessage(cid, 0),
          throwsA(anything),
        );
      });

      test('same plaintext + same key + same IV yields same ciphertext', () async {
        const cid = 'conv-deterministic';
        final key = keyManager.generateKey();
        await keyManager.storeKey(cid, key);
        const plain = 'Deterministic';
        final iv = Uint8List(16); // fixed IV so we don't call SecureRandom in test
        final c1 = EncryptionUtil.encryptWithKeyBytes(plain, key, iv);
        final c2 = EncryptionUtil.encryptWithKeyBytes(plain, key, iv);
        expect(c1, equals(c2));
      });
    });
  });
}
