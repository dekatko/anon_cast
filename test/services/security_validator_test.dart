import 'dart:convert';

import 'package:anon_cast/models/security_report.dart';
import 'package:anon_cast/services/encryption_service.dart';
import 'package:anon_cast/services/security_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/in_memory_key_storage.dart';
import '../helpers/in_memory_message_storage.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late InMemoryMessageStorage storage;
  late EncryptionService encryptionService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    storage = InMemoryMessageStorage();
    final keyStorage = InMemoryConversationKeyStorage();
    encryptionService = EncryptionService(keyStorage: keyStorage);
  });

  tearDown(() {
    storage.clear();
  });

  group('SecurityValidator', () {
    test('validateEncryption returns true when message has encryptedContent and iv', () async {
      await fakeFirestore.collection('messages').add({
        'conversationId': 'conv-1',
        'encryptedContent': base64Encode(List.generate(32, (i) => i)),
        'iv': List.generate(16, (i) => i + 1),
        'timestamp': FieldValue.serverTimestamp(),
      });
      final validator = SecurityValidator(
        firestore: fakeFirestore,
        storage: storage,
        encryption: encryptionService,
      );
      final result = await validator.validateEncryption('conv-1');
      expect(result, isTrue);
    });

    test('validateEncryption returns false when encryptedContent is missing', () async {
      await fakeFirestore.collection('messages').add({
        'conversationId': 'conv-1',
        'iv': List.generate(16, (i) => i),
        'timestamp': FieldValue.serverTimestamp(),
      });
      final validator = SecurityValidator(
        firestore: fakeFirestore,
        storage: storage,
        encryption: encryptionService,
      );
      final result = await validator.validateEncryption('conv-1');
      expect(result, isFalse);
    });

    test('validateKeysNotInFirestore returns true when no forbidden fields', () async {
      await fakeFirestore.collection('messages').add({
        'conversationId': 'c1',
        'encryptedContent': base64Encode([1, 2, 3]),
        'iv': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        'timestamp': FieldValue.serverTimestamp(),
      });
      final validator = SecurityValidator(
        firestore: fakeFirestore,
        storage: storage,
        encryption: encryptionService,
      );
      final result = await validator.validateKeysNotInFirestore();
      expect(result, isTrue);
    });

    test('validateKeysNotInFirestore returns false when key field present', () async {
      await fakeFirestore.collection('messages').add({
        'conversationId': 'c1',
        'encryptedContent': base64Encode([1, 2, 3]),
        'iv': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        'key': 'forbidden',
        'timestamp': FieldValue.serverTimestamp(),
      });
      final validator = SecurityValidator(
        firestore: fakeFirestore,
        storage: storage,
        encryption: encryptionService,
      );
      final result = await validator.validateKeysNotInFirestore();
      expect(result, isFalse);
    });

    test('validateHiveEncryption returns true', () async {
      final validator = SecurityValidator(
        firestore: fakeFirestore,
        storage: storage,
        encryption: encryptionService,
      );
      final result = await validator.validateHiveEncryption();
      expect(result, isTrue);
    });

    test('runSecurityAudit returns SecurityReport with results and timestamp', () async {
      final validator = SecurityValidator(
        firestore: fakeFirestore,
        storage: storage,
        encryption: encryptionService,
      );
      final report = await validator.runSecurityAudit();
      expect(report, isA<SecurityReport>());
      expect(report.results, isNotEmpty);
      expect(report.timestamp, isNotNull);
      expect(report.passedCount + report.failedCount, report.results.length);
    });
  });
}
