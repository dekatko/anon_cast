import 'dart:io';

import 'package:anon_cast/models/conversation_key.dart';
import 'package:anon_cast/models/message.dart';
import 'package:anon_cast/models/pending_message.dart';
import 'package:anon_cast/services/access_code_service.dart';
import 'package:anon_cast/services/conversation_key_rotation_service.dart';
import 'package:anon_cast/services/encryption_service.dart';
import 'package:anon_cast/services/local_storage_service.dart';
import 'package:anon_cast/services/message_relay.dart';
import 'package:anon_cast/services/message_service.dart';
import 'package:anon_cast/services/message_storage_interface.dart';
import 'package:anon_cast/services/offline_queue_service.dart';
import 'package:anon_cast/services/privacy_service.dart';
import 'package:anon_cast/services/security_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../helpers/in_memory_key_storage.dart';
import '../helpers/in_memory_message_storage.dart';
import '../helpers/mock_storage.dart';

// Optional: use firebase_auth_mocks for MockFirebaseAuth when available.
// Otherwise tests that need auth use a minimal stub.

const String testOrgId = 'test-org';
const String adminUid = 'test-admin-uid';
const String studentUid = 'test-student-uid';

/// Shared test environment for E2EE flow tests using fake Firestore and in-memory storage.
class E2EETestEnvironment {
  E2EETestEnvironment({
    required this.firestore,
    required this.storage,
    required this.messageService,
    required this.accessCodeService,
    this.offlineQueue,
    this.rotationService,
    this.securityValidator,
  });

  final FakeFirebaseFirestore firestore;
  final InMemoryMessageStorage storage;
  final MessageService messageService;
  final AccessCodeService accessCodeService;
  final OfflineQueueService? offlineQueue;
  final ConversationKeyRotationService? rotationService;
  final SecurityValidator? securityValidator;

  void tearDown() {
    storage.clear();
  }
}

/// Creates test environment with fake Firestore and in-memory storage.
Future<E2EETestEnvironment> setupTestEnvironment({
  bool withOfflineQueue = false,
  bool withRotationService = false,
  bool withSecurityValidator = false,
  Future<bool> Function()? isOnline,
}) async {
  final firestore = FakeFirebaseFirestore();
  final storage = InMemoryMessageStorage();
  final keyStorage = InMemoryConversationKeyStorage();
  final orgKeyStorage = InMemoryKeyManagerStorage();
  final encryption = EncryptionService(keyStorage: keyStorage);

  // Auth: use a stub that provides currentUser.uid for redeem (usedBy).
  // If firebase_auth_mocks is not available, we use a simple stub.
  final auth = _createMockAuth();

  final relay = FirestoreMessageRelay(firestore);

  final messageService = MessageService(
    firestore: firestore,
    relay: relay,
    encryptionService: encryption,
    storage: storage,
    testUserId: studentUid,
    testUserIsAnonymous: true,
    testIsOnline: isOnline ?? () async => true,
  );

  OfflineQueueService? offlineQueue;
  if (withOfflineQueue) {
    final tempDir = await Directory.systemTemp.createTemp('e2ee_offline');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(PendingMessageAdapter());
    final pendingBox = await Hive.openBox<PendingMessage>('pending_messages_e2ee_test');
    offlineQueue = OfflineQueueService(
      relay: relay,
      storage: storage,
      pendingBox: pendingBox,
    );
    await offlineQueue.init();
  }

  final accessCodeService = AccessCodeService(
    firestore: firestore,
    auth: auth,
    organizationKeyStorage: orgKeyStorage,
    encryptionService: encryption,
    storage: storage,
  );

  ConversationKeyRotationService? rotationService;
  if (withRotationService) {
    rotationService = ConversationKeyRotationService(
      storage: storage,
      relay: relay,
      encryption: encryption,
      firestore: firestore,
    );
  }

  SecurityValidator? securityValidator;
  if (withSecurityValidator) {
    securityValidator = SecurityValidator(
      firestore: firestore,
      storage: storage,
      encryption: encryption,
    );
  }

  return E2EETestEnvironment(
    firestore: firestore,
    storage: storage,
    messageService: messageService,
    accessCodeService: accessCodeService,
    offlineQueue: offlineQueue,
    rotationService: rotationService,
    securityValidator: securityValidator,
  );
}

/// Auth for tests (no Firebase.initializeApp required).
FirebaseAuth _createMockAuth() =>
    MockFirebaseAuth(mockUser: MockUser(uid: studentUid, isAnonymous: true));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2EE integration', () {
    group('1. Full message flow', () {
      test('Complete E2EE message flow: send, store, retrieve, decrypt', () async {
        final env = await setupTestEnvironment();
        addTearDown(() => env.tearDown());

        final codeData = await env.accessCodeService.generateAccessCode(
          organizationId: testOrgId,
          adminUserId: adminUid,
        );
        expect(codeData.code, isNotEmpty);
        expect(codeData.conversationId, isNotEmpty);

        final conversationData = await env.accessCodeService.redeemAccessCode(codeData.code);
        final conversationId = conversationData.conversationId;

        const testMessage = 'This is a confidential message';
        await env.messageService.sendMessage(
          conversationId: conversationId,
          content: testMessage,
        );

        final messagesSnapshot = await env.firestore
            .collection('messages')
            .where('conversationId', isEqualTo: conversationId)
            .limit(1)
            .get();
        expect(messagesSnapshot.docs, isNotEmpty);
        final encryptedContent = messagesSnapshot.docs.first.data()['encryptedContent'] as String?;
        expect(encryptedContent, isNotNull);
        expect(encryptedContent, isNot(contains(testMessage)));
        expect(encryptedContent, matches(RegExp(r'^[A-Za-z0-9+/=]+$')));

        final messages = await env.messageService.watchConversation(conversationId).first;
        expect(messages.length, 1);
        expect(messages.first.content, testMessage);

        final storedMessage = await env.storage.getMessage(messages.first.id);
        expect(storedMessage?.content, testMessage);
      });
    });

    group('2. Offline queue', () {
      test('Messages queue offline and sync when online', () async {
        final env = await setupTestEnvironment(withOfflineQueue: true);
        addTearDown(() => env.tearDown());

        final codeData = await env.accessCodeService.generateAccessCode(
          organizationId: testOrgId,
          adminUserId: adminUid,
        );
        await env.accessCodeService.redeemAccessCode(codeData.code);
        final conversationId = codeData.conversationId;

        final messageServiceOffline = MessageService(
          firestore: env.firestore,
          relay: FirestoreMessageRelay(env.firestore),
          encryptionService: EncryptionService(keyStorage: InMemoryConversationKeyStorage()),
          storage: env.storage,
          offlineQueue: env.offlineQueue,
          testUserId: studentUid,
          testUserIsAnonymous: true,
          testIsOnline: () async => false,
        );

        await messageServiceOffline.sendMessage(
          conversationId: conversationId,
          content: 'Offline message',
        );

        final pending = env.offlineQueue!.getPendingMessages(conversationId);
        expect(pending.length, 1);
        expect(pending.first.status, PendingMessageStatus.pending);

        await env.offlineQueue!.processQueue();

        await Future<void>.delayed(const Duration(milliseconds: 500));

        final messagesSnapshot = await env.firestore
            .collection('messages')
            .where('conversationId', isEqualTo: conversationId)
            .get();
        expect(messagesSnapshot.docs.length, 1);

        final pendingAfter = env.offlineQueue!.getPendingMessages(conversationId);
        expect(pendingAfter.length, 0);
      });
    });

    group('3. Key rotation', () {
      test('Key rotation re-encrypts messages correctly', () async {
        final env = await setupTestEnvironment(withRotationService: true);
        addTearDown(() => env.tearDown());

        final codeData = await env.accessCodeService.generateAccessCode(
          organizationId: testOrgId,
          adminUserId: adminUid,
        );
        await env.accessCodeService.redeemAccessCode(codeData.code);
        final conversationId = codeData.conversationId;

        for (int i = 0; i < 5; i++) {
          await env.messageService.sendMessage(
            conversationId: conversationId,
            content: 'Message $i',
          );
        }

        final keyBefore = await env.storage.getConversationKeyFull(conversationId);
        expect(keyBefore, isNotNull);
        final versionBefore = keyBefore!.version;

        await env.rotationService!.rotateKey(conversationId);

        final keyAfter = await env.storage.getConversationKeyFull(conversationId);
        expect(keyAfter, isNotNull);
        expect(keyAfter!.version, versionBefore + 1);
        expect(keyAfter.oldKeys.length, 1);
        expect(keyAfter.oldKeys.first.version, versionBefore);

        final messages = await env.messageService.watchConversation(conversationId).first;
        expect(messages.length, 5);
        for (int i = 0; i < 5; i++) {
          expect(messages[i].content, 'Message $i');
        }
      });
    });

    group('4. Security validation', () {
      test('Security validator fails when plaintext is in Firestore', () async {
        final env = await setupTestEnvironment(withSecurityValidator: true);
        addTearDown(() => env.tearDown());

        final codeData = await env.accessCodeService.generateAccessCode(
          organizationId: testOrgId,
          adminUserId: adminUid,
        );
        await env.accessCodeService.redeemAccessCode(codeData.code);
        final conversationId = codeData.conversationId;

        await env.firestore.collection('messages').add({
          'conversationId': conversationId,
          'content': 'PLAINTEXT LEAK',
          'timestamp': FieldValue.serverTimestamp(),
        });

        final report = await env.securityValidator!.runSecurityAudit(
          conversationIdsToCheck: [conversationId],
        );

        expect(report.allPassed, isFalse);
        final encryptionResult = report.results.where((r) => r.name == 'Message encryption').toList();
        expect(encryptionResult, isNotEmpty);
        expect(encryptionResult.first.passed, isFalse);
      });
    });

    group('5. Cleanup / logout', () {
      test('Clearing storage removes all messages and keys', () async {
        final env = await setupTestEnvironment();
        addTearDown(() => env.tearDown());

        final codeData = await env.accessCodeService.generateAccessCode(
          organizationId: testOrgId,
          adminUserId: adminUid,
        );
        await env.accessCodeService.redeemAccessCode(codeData.code);
        final conversationId = codeData.conversationId;

        await env.messageService.sendMessage(
          conversationId: conversationId,
          content: 'Secret message',
        );

        expect(await env.storage.getAllMessageIds(), isNotEmpty);
        expect(await env.storage.getAllConversationKeys(), isNotEmpty);

        env.storage.clear();

        expect(await env.storage.getAllMessageIds(), isEmpty);
        expect(await env.storage.getAllConversationKeys(), isEmpty);
      });

      test('Logout clears all sensitive data (with real LocalStorageService)', () async {
        final tempDir = await Directory.systemTemp.createTemp('e2ee_cleanup');
        Hive.init(tempDir.path);
        if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(MessageAdapter());
        if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(ConversationKeyAdapter());
        if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(PendingMessageAdapter());

        await LocalStorageService.instance.init();
        final firestore = FakeFirebaseFirestore();
        final relay = FirestoreMessageRelay(firestore);
        final encryption = EncryptionService();
        final messageService = MessageService(
          firestore: firestore,
          relay: relay,
          encryptionService: encryption,
          storage: LocalStorageService.instance,
          testUserId: studentUid,
          testUserIsAnonymous: true,
          testIsOnline: () async => true,
        );

        final conversationId = 'cleanup-conv-1';
        await LocalStorageService.instance.storeConversationKey(
          conversationId,
          'dummy-base64-key-for-test',
        );
        await messageService.sendMessage(
          conversationId: conversationId,
          content: 'Secret message',
        );

        expect(await LocalStorageService.instance.getAllMessageIds(), isNotEmpty);
        expect(await LocalStorageService.instance.getAllConversationKeys(), isNotEmpty);

        final privacyService = PrivacyService(
          storage: LocalStorageService.instance,
          auth: _createMockAuth(),
        );
        await privacyService.clearAllLocalData();

        await LocalStorageService.instance.init();
        expect(await LocalStorageService.instance.getAllMessageIds(), isEmpty);
        expect(await LocalStorageService.instance.getAllConversationKeys(), isEmpty);
      }, skip: 'Requires path_provider platform channel; run as integration test on device');
    });
  });
}
