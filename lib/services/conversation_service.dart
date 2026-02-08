import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/conversation.dart';
import 'encryption_service.dart';
import 'local_storage_service.dart';
import 'message_storage_interface.dart';

/// Thrown when conversation create/update/delete or permission check fails.
class ConversationServiceException implements Exception {
  const ConversationServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ConversationServiceException: $message${cause != null ? ' | cause: $cause' : ''}';
}

/// Manages conversation documents (Firestore) and encryption key handling (Hive).
/// No sensitive data is stored in Firestore; keys and message content stay in Hive.
class ConversationService {
  ConversationService({
    required FirebaseFirestore firestore,
    EncryptionService? encryptionService,
    MessageServiceStorage? storage,
    Logger? logger,
    /// When non-null, [deleteConversation] and [updateStatus] require this to return true.
    Future<bool> Function(String conversationId, String userId)? requireAdminPermission,
  })  : _firestore = firestore,
        _encryption = encryptionService ?? EncryptionService(),
        _storage = storage ?? LocalStorageService.instance,
        _log = logger ?? Logger(),
        _requireAdminPermission = requireAdminPermission;

  final FirebaseFirestore _firestore;
  final EncryptionService _encryption;
  final MessageServiceStorage _storage;
  final Logger _log;
  final Future<bool> Function(String conversationId, String userId)? _requireAdminPermission;

  static const String _conversationsCollection = 'conversations';

  /// Creates a new conversation: generates id and encryption key, stores key in Hive, writes metadata to Firestore.
  ///
  /// Steps: (a) generate conversation id, (b) generate key via [EncryptionService],
  /// (c) store key locally in Hive, (d) create conversation document in Firestore (no keys).
  Future<Conversation> createConversation({
    required String organizationId,
    required String adminUserId,
    Map<String, dynamic>? metadata,
  }) async {
    if (organizationId.isEmpty || adminUserId.isEmpty) {
      throw ConversationServiceException('organizationId and adminUserId are required.');
    }

    final conversationId = 'conv_${const Uuid().v4().replaceAll('-', '')}';
    final key = await _encryption.generateConversationKey();
    await _encryption.storeKeyLocally(conversationId, key);
    await _storage.storeConversationKey(conversationId, key);

    final now = DateTime.now();
    final doc = {
      'id': conversationId,
      'organizationId': organizationId,
      'createdBy': adminUserId,
      'adminId': adminUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': ConversationStatus.active.value,
      'lastMessageAt': Timestamp.fromDate(now),
      'messageCount': 0,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };

    await _firestore.collection(_conversationsCollection).doc(conversationId).set(doc);

    _log.i('ConversationService: created conversation $conversationId for org $organizationId by $adminUserId');
    return Conversation(
      id: conversationId,
      organizationId: organizationId,
      adminId: adminUserId,
      createdBy: adminUserId,
      createdAt: now,
      messageCount: 0,
      status: ConversationStatus.active,
      metadata: metadata,
    );
  }

  /// Fetches conversation metadata from Firestore and enriches with latest message preview from Hive.
  Future<Conversation?> getConversation(String conversationId) async {
    if (conversationId.isEmpty) return null;

    try {
      final ref = _firestore.collection(_conversationsCollection).doc(conversationId);
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.data() == null) return null;

      final conv = Conversation.fromFirestore(snapshot);
      final messages = await _storage.getConversationMessages(conversationId);
      final last = messages.isNotEmpty ? messages.last : null;
      final preview = last?.content ?? last?.preview;
      return conv.copyWith(
        lastMessagePreview: preview != null && preview.isNotEmpty ? preview : null,
      );
    } on Exception catch (e, st) {
      _log.e('ConversationService: getConversation failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Streams conversations where [userId] is a participant (createdBy or anonymousUserId), sorted by lastMessageAt descending.
  /// Enriches with unread counts from Hive.
  Stream<List<Conversation>> watchUserConversations(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    QuerySnapshot<Map<String, dynamic>>? latestByCreated;
    QuerySnapshot<Map<String, dynamic>>? latestByAnonymous;
    final controller = StreamController<List<Conversation>>.broadcast();

    Future<void> mergeAndEmit() async {
      final seen = <String>{};
      final list = <Conversation>[];
      if (latestByCreated != null) {
        for (final doc in latestByCreated!.docs) {
          if (seen.add(doc.id)) {
            try {
              list.add(Conversation.fromFirestore(doc));
            } catch (_) {}
          }
        }
      }
      if (latestByAnonymous != null) {
        for (final doc in latestByAnonymous!.docs) {
          if (seen.add(doc.id)) {
            try {
              list.add(Conversation.fromFirestore(doc));
            } catch (_) {}
          }
        }
      }
      list.sort((a, b) {
        final aAt = a.lastMessageAt ?? a.createdAt;
        final bAt = b.lastMessageAt ?? b.createdAt;
        return bAt.compareTo(aAt);
      });
      final enriched = <Conversation>[];
      for (final c in list) {
        final unread = await _unreadCount(c.id);
        enriched.add(c.copyWith(unreadCount: unread));
      }
      if (!controller.isClosed) controller.add(enriched);
    }

    final subCreated = _firestore
        .collection(_conversationsCollection)
        .where('createdBy', isEqualTo: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .listen((snap) {
      latestByCreated = snap;
      mergeAndEmit();
    }, onError: controller.addError);

    final subAnonymous = _firestore
        .collection(_conversationsCollection)
        .where('anonymousUserId', isEqualTo: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .listen((snap) {
      latestByAnonymous = snap;
      mergeAndEmit();
    }, onError: controller.addError);

    controller.onCancel = () {
      subCreated.cancel();
      subAnonymous.cancel();
    };

    return controller.stream;
  }

  Future<int> _unreadCount(String conversationId) async {
    try {
      final messages = await _storage.getConversationMessages(conversationId);
      return messages.where((m) => m.isUnread).length;
    } catch (_) {
      return 0;
    }
  }

  /// Updates conversation status (e.g. resolved, archived). Requires admin permission if [requireAdminPermission] is set.
  Future<void> updateStatus(String conversationId, ConversationStatus status, String userId) async {
    if (conversationId.isEmpty) {
      throw ConversationServiceException('conversationId is required.');
    }
    if (_requireAdminPermission != null && !await _requireAdminPermission!(conversationId, userId)) {
      _log.w('ConversationService: updateStatus permission denied for $conversationId');
      throw ConversationServiceException('Permission denied.');
    }

    try {
      await _firestore.collection(_conversationsCollection).doc(conversationId).update({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _log.d('ConversationService: updated status $conversationId to ${status.value}');
    } on FirebaseException catch (e) {
      _log.e('ConversationService: updateStatus failed', error: e);
      throw ConversationServiceException('Failed to update status', cause: e);
    }
  }

  /// Returns metadata for a conversation: message count, unread count, last message time, has encryption key (from Hive).
  Future<ConversationMetadata> getMetadata(String conversationId) async {
    if (conversationId.isEmpty) {
      return const ConversationMetadata(messageCount: 0, unreadCount: 0);
    }

    try {
      final messages = await _storage.getConversationMessages(conversationId);
      final unreadCount = messages.where((m) => m.isUnread).length;
      final lastMessageAt = messages.isNotEmpty
          ? messages.map((m) => m.timestamp).reduce((a, b) => a.isAfter(b) ? a : b)
          : null;
      final hasKey = await _encryption.hasKey(conversationId);
      return ConversationMetadata(
        messageCount: messages.length,
        unreadCount: unreadCount,
        lastMessageAt: lastMessageAt,
        hasEncryptionKey: hasKey,
      );
    } catch (e, st) {
      _log.e('ConversationService: getMetadata failed', error: e, stackTrace: st);
      return const ConversationMetadata(messageCount: 0, unreadCount: 0);
    }
  }

  /// Deletes conversation from Firestore and all local data (messages + encryption key). Requires admin permission if set.
  Future<void> deleteConversation(String conversationId, String userId) async {
    if (conversationId.isEmpty) return;
    if (_requireAdminPermission != null && !await _requireAdminPermission!(conversationId, userId)) {
      _log.w('ConversationService: deleteConversation permission denied for $conversationId');
      throw ConversationServiceException('Permission denied. Admin required.');
    }

    try {
      await _firestore.collection(_conversationsCollection).doc(conversationId).delete();
    } on FirebaseException catch (e) {
      _log.w('ConversationService: Firestore delete failed (may be offline)', error: e);
    }
    await _storage.deleteConversation(conversationId);
    await _encryption.deleteKey(conversationId);
    _log.i('ConversationService: deleted conversation $conversationId');
  }
}
