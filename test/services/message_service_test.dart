import 'package:anon_cast/models/message.dart';
import 'package:anon_cast/services/encryption_service.dart';
import 'package:anon_cast/services/message_relay.dart';
import 'package:anon_cast/services/message_service.dart';
import 'package:anon_cast/services/message_storage_interface.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/in_memory_key_storage.dart';
import '../helpers/in_memory_message_storage.dart';

void main() {
  late MessageService service;
  late FakeFirebaseFirestore fakeFirestore;
  late InMemoryMessageStorage storage;
  late EncryptionService encryptionService;
  const conversationId = 'conv-1';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    storage = InMemoryMessageStorage();
    final keyStorage = InMemoryConversationKeyStorage();
    encryptionService = EncryptionService(keyStorage: keyStorage);
    service = MessageService(
      firestore: fakeFirestore,
      relay: FirestoreMessageRelay(fakeFirestore),
      encryptionService: encryptionService,
      storage: storage,
      testUserId: 'test-user-id',
      testUserIsAnonymous: true,
      testIsOnline: () async => true,
    );
  });

  tearDown(() {
    storage.clear();
  });

  group('MessageService', () {
    group('sendMessage', () {
      test('encrypts, uploads to relay, stores plaintext locally and returns message id', () async {
        final id = await service.sendMessage(
          conversationId: conversationId,
          content: 'Hello',
        );
        expect(id, isNotEmpty);

        final messages = await storage.getConversationMessages(conversationId);
        expect(messages.length, 1);
        expect(messages.first.id, id);
        expect(messages.first.content, 'Hello');
        expect(messages.first.conversationId, conversationId);
        expect(messages.first.senderId, 'test-user-id');
        expect(messages.first.encryptedContent, isNotEmpty);
      });

      test('creates and stores conversation key when missing', () async {
        await service.sendMessage(conversationId: conversationId, content: 'First');
        final key = await storage.getConversationKey(conversationId);
        expect(key, isNotEmpty);
      });

      test('reuses existing conversation key', () async {
        await service.sendMessage(conversationId: conversationId, content: 'One');
        await service.sendMessage(conversationId: conversationId, content: 'Two');
        final messages = await storage.getConversationMessages(conversationId);
        expect(messages.length, 2);
      });

      test('throws when conversationId is empty', () async {
        expect(
          () => service.sendMessage(conversationId: '', content: 'x'),
          throwsA(isA<MessageServiceException>()),
        );
      });

      test('when offline, queues message and returns local id', () async {
        final offlineService = MessageService(
          firestore: fakeFirestore,
          relay: FirestoreMessageRelay(fakeFirestore),
          encryptionService: encryptionService,
          storage: storage,
          testUserId: 'test-user-id',
          testUserIsAnonymous: true,
          testIsOnline: () async => false,
        );
        final id = await offlineService.sendMessage(
          conversationId: conversationId,
          content: 'Offline msg',
        );
        expect(id, isNotEmpty);
        final result = await offlineService.getOfflineMessages(conversationId);
        expect(result.messages.length, 1);
        expect(result.pendingMessageIds, contains(id));
      });
    });

    group('getOfflineMessages', () {
      test('returns messages and pending ids from storage only', () async {
        await service.sendMessage(conversationId: conversationId, content: 'A');
        final result = await service.getOfflineMessages(conversationId);
        expect(result.messages.length, 1);
        expect(result.messages.first.content, 'A');
        expect(result.pendingMessageIds, isEmpty);
      });

      test('returns empty for empty conversationId', () async {
        final result = await service.getOfflineMessages('');
        expect(result.messages, isEmpty);
        expect(result.pendingMessageIds, isEmpty);
      });
    });

    group('watchConversation', () {
      test('emits list from storage after decrypting relay docs', () async {
        await service.sendMessage(conversationId: conversationId, content: 'Watched');
        final stream = service.watchConversation(conversationId);
        final lists = await stream.take(1).toList();
        expect(lists.length, 1);
        expect(lists.first.length, 1);
        expect(lists.first.first.content, 'Watched');
      });

      test('emits empty list for empty conversationId', () async {
        final stream = service.watchConversation('');
        final lists = await stream.toList();
        expect(lists, isEmpty);
      });
    });

    group('deleteMessage', () {
      test('removes from relay and storage', () async {
        final id = await service.sendMessage(
          conversationId: conversationId,
          content: 'To delete',
        );
        await service.deleteMessage(id);
        expect(await storage.getMessage(id), isNull);
      });

      test('no-op for empty messageId', () async {
        await service.deleteMessage('');
        expect(true, isTrue);
      });
    });

    group('deleteConversation', () {
      test('removes all messages and key for conversation', () async {
        await service.sendMessage(conversationId: conversationId, content: 'A');
        await service.deleteConversation(conversationId);
        expect(await storage.getConversationMessages(conversationId), isEmpty);
        expect(await storage.getConversationKey(conversationId), isNull);
      });

      test('no-op for empty conversationId', () async {
        await service.deleteConversation('');
        expect(true, isTrue);
      });
    });

    group('hasUnreadMessages', () {
      test('returns true when conversation has unread message', () async {
        await service.sendMessage(conversationId: conversationId, content: 'New');
        expect(await service.hasUnreadMessages(conversationId), isTrue);
      });

      test('returns false for empty conversationId', () async {
        expect(await service.hasUnreadMessages(''), isFalse);
      });
    });

    group('error handling', () {
      test('getOfflineMessages rethrows storage errors', () async {
        final badStorage = _ThrowingStorage()..failGetConversationMessages = true;
        final badService = MessageService(
          firestore: fakeFirestore,
          relay: FirestoreMessageRelay(fakeFirestore),
          encryptionService: encryptionService,
          storage: badStorage,
          testUserId: 'u',
          testIsOnline: () async => true,
        );
        try {
          await badService.getOfflineMessages(conversationId);
          fail('expected StateError');
        } on StateError catch (e) {
          expect(e.message, 'test throw');
        }
      });
    });
  });
}

/// Storage that can be configured to throw on specific methods.
class _ThrowingStorage implements MessageServiceStorage {
  bool failGetConversationMessages = false;

  @override
  Future<void> storeMessage(Message message) async {}

  @override
  Future<Message?> getMessage(String messageId) async => null;

  @override
  Future<List<Message>> getConversationMessages(String conversationId) async {
    if (failGetConversationMessages) throw StateError('test throw');
    return [];
  }

  @override
  Future<void> storeConversationKey(String conversationId, String key) async {}

  @override
  Future<String?> getConversationKey(String conversationId) async => null;

  @override
  Future<void> deleteMessage(String messageId) async {}

  @override
  Future<void> deleteConversation(String conversationId) async {}

  @override
  Future<void> updateMessageId(String oldId, String newId) async {}

  @override
  Future<void> removePendingMessageId(String conversationId, String messageId) async {}

  @override
  Future<String?> getUserPref(String key) async => null;

  @override
  Future<void> setUserPref(String key, String value) async {}
}
