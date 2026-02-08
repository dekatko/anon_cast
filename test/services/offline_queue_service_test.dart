import 'package:anon_cast/models/message.dart';
import 'package:anon_cast/models/pending_message.dart';
import 'package:anon_cast/services/message_relay.dart';
import 'package:anon_cast/services/offline_queue_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

import '../helpers/in_memory_message_storage.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late InMemoryMessageStorage storage;
  late Box<PendingMessage> box;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('offline_queue_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(PendingMessageAdapter());
    }
  });

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    storage = InMemoryMessageStorage();
    box = await Hive.openBox<PendingMessage>('pending_messages_test');
  });

  tearDown(() async {
    await box.clear();
    await box.close();
    await Hive.deleteBoxFromDisk('pending_messages_test');
  });

  group('OfflineQueueService', () {
    test('queueMessage adds and getPendingMessages returns by conversationId', () async {
      final relay = FirestoreMessageRelay(fakeFirestore);
      final queue = OfflineQueueService(
        relay: relay,
        storage: storage,
        pendingBox: box,
      );
      await queue.init();

      final msg = PendingMessage(
        id: 'local-1',
        conversationId: 'conv-1',
        encryptedContent: 'enc',
        iv: [1, 2, 3],
        timestamp: DateTime.now(),
        senderId: 'user-1',
        senderType: 'anonymous',
        preview: 'preview',
      );
      await queue.queueMessage(msg);

      final list = queue.getPendingMessages('conv-1');
      expect(list.length, 1);
      expect(list.first.id, 'local-1');
      expect(queue.getPendingMessages('other'), isEmpty);
    });

    test('processQueue sends to relay and updates storage id then removes from queue', () async {
      final relay = FirestoreMessageRelay(fakeFirestore);
      final queue = OfflineQueueService(
        relay: relay,
        storage: storage,
        pendingBox: box,
      );
      await queue.init();

      const localId = 'local-1';
      const conversationId = 'conv-1';
      final now = DateTime.now();
      await storage.storeMessage(Message(
        id: localId,
        conversationId: conversationId,
        senderId: 'user-1',
        encryptedContent: 'enc',
        content: 'Hello',
        timestamp: now,
        status: MessageStatus.unread,
        iv: [1, 2, 3],
        preview: 'preview',
        senderType: 'anonymous',
      ));
      final pending = PendingMessage(
        id: localId,
        conversationId: conversationId,
        encryptedContent: 'enc',
        iv: [1, 2, 3],
        timestamp: now,
        senderId: 'user-1',
        senderType: 'anonymous',
        preview: 'preview',
      );
      await queue.queueMessage(pending);

      await queue.processQueue();

      expect(queue.getPendingMessages(conversationId), isEmpty);
      expect(await storage.getMessage(localId), isNull);
      final convMessages = await storage.getConversationMessages(conversationId);
      expect(convMessages.length, 1);
      expect(convMessages.single.id, isNotEmpty);
      expect(convMessages.single.id, isNot(equals(localId)));
    });

    test('removeFromQueue and clearQueue', () async {
      final queue = OfflineQueueService(relay: null, storage: storage, pendingBox: box);
      await queue.init();
      final msg = PendingMessage(
        id: 'x',
        conversationId: 'c',
        encryptedContent: 'e',
        iv: [],
        timestamp: DateTime.now(),
      );
      await queue.queueMessage(msg);
      expect(queue.getPendingMessages('c').length, 1);
      await queue.removeFromQueue('x');
      expect(queue.getPendingMessages('c'), isEmpty);
      await queue.queueMessage(msg);
      await queue.clearQueue();
      expect(queue.getPendingMessages('c'), isEmpty);
    });
  });
}
