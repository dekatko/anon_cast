import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/pending_message.dart';
import 'encryption_service.dart';
import 'local_storage_service.dart';
import 'message_relay.dart';
import 'message_storage_interface.dart';
import 'offline_queue_service.dart';

/// Thrown when message send/receive or key operations fail.
class MessageServiceException implements Exception {
  const MessageServiceException(this.message, {this.cause, this.conversationId});

  final String message;
  final Object? cause;
  final String? conversationId;

  @override
  String toString() =>
      'MessageServiceException: $message'
      '${conversationId != null ? ' (conversationId: $conversationId)' : ''}'
      '${cause != null ? ' | cause: $cause' : ''}';
}

/// Result of [getOfflineMessages]: messages plus ids that are pending upload.
class OfflineMessagesResult {
  const OfflineMessagesResult({required this.messages, required this.pendingMessageIds});

  final List<Message> messages;
  final Set<String> pendingMessageIds;
}

/// End-to-end encrypted message flow: Firestore as encrypted relay, Hive for local decrypted storage.
/// SEND: plaintext → encrypt → upload to Firestore → store plaintext in Hive.
/// RECEIVE: Firestore snapshot → decrypt → store in Hive → emit from Hive.
class MessageService {
  MessageService({
    required FirebaseFirestore firestore,
    FirebaseAuth? auth,
    MessageRelay? relay,
    EncryptionService? encryptionService,
    MessageServiceStorage? storage,
    OfflineQueueService? offlineQueue,
    Logger? logger,
    /// Test override: when non-null, used instead of [auth?.currentUser] for send.
    String? testUserId,
    bool? testUserIsAnonymous,
    /// Test override: when non-null, used instead of connectivity check (e.g. () async => true).
    Future<bool> Function()? testIsOnline,
  })  : _relay = relay ?? FirestoreMessageRelay(firestore),
        _auth = auth,
        _encryption = encryptionService ?? EncryptionService(),
        _storage = storage ?? LocalStorageService.instance,
        _offlineQueue = offlineQueue,
        _log = logger ?? Logger(),
        _testUserId = testUserId,
        _testUserIsAnonymous = testUserIsAnonymous,
        _testIsOnline = testIsOnline;

  final MessageRelay _relay;
  final FirebaseAuth? _auth;
  final EncryptionService _encryption;
  final MessageServiceStorage _storage;
  final OfflineQueueService? _offlineQueue;
  final Logger _log;
  final String? _testUserId;
  final bool? _testUserIsAnonymous;
  final Future<bool> Function()? _testIsOnline;

  String get _senderId => _testUserId ?? _auth?.currentUser?.uid ?? '';
  bool get _senderIsAnonymous => _testUserIsAnonymous ?? (_auth?.currentUser?.isAnonymous == true);
  static const String _pendingPrefPrefix = 'message_service_pending_';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Gets or creates the conversation encryption key (from Hive or generates and stores).
  Future<String> _getOrCreateKey(String conversationId) async {
    var key = await _storage.getConversationKey(conversationId);
    if (key != null && key.isNotEmpty) return key;
    key = await _encryption.generateConversationKey();
    await _encryption.storeKeyLocally(conversationId, key);
    await _storage.storeConversationKey(conversationId, key);
    _log.d('MessageService: created new key for $conversationId');
    return key;
  }

  Future<bool> _isOnline() async {
    if (_testIsOnline != null) return _testIsOnline!();
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> _addPending(String conversationId, String messageId) async {
    final key = '$_pendingPrefPrefix$conversationId';
    final json = await _storage.getUserPref(key);
    final list = json != null && json.isNotEmpty
        ? (List<String>.from(jsonDecode(json) as List<dynamic>))
        : <String>[];
    if (!list.contains(messageId)) {
      list.add(messageId);
      await _storage.setUserPref(key, jsonEncode(list));
    }
  }

  Future<void> _removePending(String conversationId, String messageId) async {
    final key = '$_pendingPrefPrefix$conversationId';
    final json = await _storage.getUserPref(key);
    if (json == null || json.isEmpty) return;
    final list = List<String>.from(jsonDecode(json) as List<dynamic>);
    list.remove(messageId);
    if (list.isEmpty) {
      await _storage.setUserPref(key, '');
    } else {
      await _storage.setUserPref(key, jsonEncode(list));
    }
  }

  Future<Set<String>> _getPendingIds(String conversationId) async {
    final key = '$_pendingPrefPrefix$conversationId';
    final json = await _storage.getUserPref(key);
    if (json == null || json.isEmpty) return {};
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => e as String).toSet();
  }

  Future<void> _clearPending(String conversationId) async {
    await _storage.setUserPref('$_pendingPrefPrefix$conversationId', '');
  }

  /// Sends a message: encrypt → Firestore → store plaintext in Hive. Offline: queue and store locally.
  /// Returns the message id (Firestore doc id or local id if queued).
  Future<String> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    if (conversationId.isEmpty) {
      throw MessageServiceException('conversationId must not be empty.', conversationId: conversationId);
    }
    final senderId = _senderId;
    final senderType = _senderIsAnonymous ? 'anonymous' : 'admin';
    final now = DateTime.now();

    String key;
    try {
      key = await _getOrCreateKey(conversationId);
    } on EncryptionServiceException catch (e) {
      _log.e('MessageService: no key for send', error: e);
      throw MessageServiceException(
        'Encryption key not available: ${e.message}',
        conversationId: conversationId,
        cause: e,
      );
    }

    EncryptedMessage encrypted;
    try {
      encrypted = await _encryption.encryptMessage(content, key);
    } on EncryptionServiceException catch (e) {
      _log.e('MessageService: encrypt failed', error: e);
      throw MessageServiceException('Encryption failed', conversationId: conversationId, cause: e);
    }

    final online = await _isOnline();
    if (!online) {
      final localId = const Uuid().v4();
      final preview = content.length > 100 ? '${content.substring(0, 100)}…' : content;
      final message = Message(
        id: localId,
        conversationId: conversationId,
        senderId: senderId,
        encryptedContent: encrypted.encryptedContent,
        content: content,
        timestamp: now,
        status: MessageStatus.unread,
        iv: _ivToList(encrypted.iv),
        preview: preview,
        senderType: senderType,
      );
      await _storage.storeMessage(message);
      await _addPending(conversationId, localId);
      if (_offlineQueue != null) {
        final pending = PendingMessage(
          id: localId,
          conversationId: conversationId,
          encryptedContent: encrypted.encryptedContent,
          iv: _ivToList(encrypted.iv),
          timestamp: now,
          senderId: senderId,
          senderType: senderType,
          preview: preview,
        );
        await _offlineQueue!.queueMessage(pending);
      }
      _log.d('MessageService: queued offline message $localId');
      return localId;
    }

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final data = {
          'conversationId': conversationId,
          'senderId': senderId,
          'senderType': senderType,
          'encryptedContent': encrypted.encryptedContent,
          'iv': _ivToList(encrypted.iv),
          'preview': content.length > 100 ? '${content.substring(0, 100)}…' : content,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'unread',
        };
        final messageId = await _relay.add(data);
        final message = Message(
          id: messageId,
          conversationId: conversationId,
          senderId: senderId,
          encryptedContent: encrypted.encryptedContent,
          content: content,
          timestamp: now,
          status: MessageStatus.unread,
          iv: _ivToList(encrypted.iv),
          preview: data['preview'] as String?,
          senderType: senderType,
        );
        await _storage.storeMessage(message);
        _log.d('MessageService: sent message $messageId');
        return messageId;
      } on FirebaseException catch (e) {
        _log.w('MessageService: Firestore send attempt ${attempt + 1} failed', error: e);
        if (attempt == _maxRetries - 1) {
          final localId = const Uuid().v4();
          final preview = content.length > 100 ? '${content.substring(0, 100)}…' : content;
          final pendingMessage = Message(
            id: localId,
            conversationId: conversationId,
            senderId: senderId,
            encryptedContent: encrypted.encryptedContent,
            content: content,
            timestamp: now,
            status: MessageStatus.unread,
            iv: _ivToList(encrypted.iv),
            preview: preview,
            senderType: senderType,
          );
          await _storage.storeMessage(pendingMessage);
          await _addPending(conversationId, localId);
          if (_offlineQueue != null) {
            final pending = PendingMessage(
              id: localId,
              conversationId: conversationId,
              encryptedContent: encrypted.encryptedContent,
              iv: _ivToList(encrypted.iv),
              timestamp: now,
              senderId: senderId,
              senderType: senderType,
              preview: preview,
            );
            await _offlineQueue!.queueMessage(pending);
          }
          _log.d('MessageService: queued after failure: $localId');
          return localId;
        }
        await Future<void>.delayed(_retryDelay);
      }
    }
    throw MessageServiceException('Send failed after $_maxRetries attempts', conversationId: conversationId);
  }

  List<int> _ivToList(String ivBase64) {
    return base64Decode(ivBase64);
  }

  /// Listens to Firestore, decrypts new/updated messages, stores in Hive, emits list from Hive.
  Stream<List<Message>> watchConversation(String conversationId) async* {
    if (conversationId.isEmpty) return;
    String? key;
    try {
      key = await _storage.getConversationKey(conversationId);
    } catch (e, st) {
      _log.e('MessageService: get key failed in watch', error: e, stackTrace: st);
    }
    if (key == null || key.isEmpty) {
        _log.w('MessageService: no key for conversation $conversationId; cannot decrypt');
        yield await _storage.getConversationMessages(conversationId);
        return;
    }

    final snapshots = _relay.watch(conversationId);

    await for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        final existing = await _storage.getMessage(doc.id);
        if (existing != null && existing.content != null && existing.content!.isNotEmpty) {
          continue;
        }
        final data = doc.data();
        final encryptedContent = data['encryptedContent'] as String? ?? '';
        final ivRaw = data['iv'];
        if (encryptedContent.isEmpty) continue;
        String? ivBase64;
        if (ivRaw is List) {
          ivBase64 = base64Encode(ivRaw.cast<int>());
        } else if (ivRaw != null) {
          continue;
        }
        if (ivBase64 == null) continue;
        try {
          final plaintext = await _encryption.decryptMessage(encryptedContent, ivBase64, key);
          final convId = data['conversationId'] as String? ?? conversationId;
          final senderId = data['senderId'] as String? ?? '';
          final status = MessageStatusX.fromString(data['status'] as String?);
          final ts = data['timestamp'];
          DateTime timestamp = DateTime.now();
          if (ts is Timestamp) timestamp = ts.toDate();
          if (ts is int) timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
          final msg = Message(
            id: doc.id,
            conversationId: convId,
            senderId: senderId,
            encryptedContent: encryptedContent,
            content: plaintext,
            timestamp: timestamp,
            status: status,
            iv: ivRaw is List ? ivRaw.cast<int>() : null,
            preview: data['preview'] as String?,
            senderType: data['senderType'] as String?,
          );
          await _storage.storeMessage(msg);
        } on EncryptionServiceException catch (e) {
          _log.w('MessageService: decrypt failed for ${doc.id}', error: e);
        } catch (e, st) {
          _log.w('MessageService: decrypt error for ${doc.id}', error: e, stackTrace: st);
        }
      }
      final list = await _storage.getConversationMessages(conversationId);
      yield list;
    }
  }

  /// Returns messages from Hive only (no Firestore). Includes which message ids are pending upload.
  Future<OfflineMessagesResult> getOfflineMessages(String conversationId) async {
    if (conversationId.isEmpty) {
      return const OfflineMessagesResult(messages: [], pendingMessageIds: {});
    }
    try {
      final messages = await _storage.getConversationMessages(conversationId);
      final pending = await _getPendingIds(conversationId);
      return OfflineMessagesResult(messages: messages, pendingMessageIds: pending);
    } catch (e, st) {
      _log.e('MessageService: getOfflineMessages failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Returns pending queue entries for [conversationId] (for UI: "Sending...", "Failed ⚠️").
  /// Empty if [OfflineQueueService] is not set.
  List<PendingMessage> getPendingQueueMessages(String conversationId) {
    if (conversationId.isEmpty) return [];
    return _offlineQueue?.getPendingMessages(conversationId) ?? [];
  }

  /// Deletes message from Firestore and Hive. Removes from pending if present.
  Future<void> deleteMessage(String messageId) async {
    if (messageId.isEmpty) return;
    try {
      await _relay.delete(messageId);
    } on FirebaseException catch (e) {
      _log.w('MessageService: Firestore deleteMessage failed (may be offline)', error: e);
    }
    final msg = await _storage.getMessage(messageId);
    if (msg != null) {
      await _removePending(msg.conversationId, messageId);
    }
    await _storage.deleteMessage(messageId);
    _log.d('MessageService: deleted message $messageId');
  }

  /// Removes all messages and the conversation key for [conversationId].
  Future<void> deleteConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    try {
      await _clearPending(conversationId);
      await _storage.deleteConversation(conversationId);
      await _encryption.deleteKey(conversationId);
      _log.d('MessageService: deleted conversation $conversationId');
    } catch (e, st) {
      _log.e('MessageService: deleteConversation failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Returns true if any message in the conversation is unread (from Hive).
  Future<bool> hasUnreadMessages(String conversationId) async {
    if (conversationId.isEmpty) return false;
    try {
      final list = await _storage.getConversationMessages(conversationId);
      return list.any((m) => m.isUnread);
    } catch (e, st) {
      _log.e('MessageService: hasUnreadMessages failed', error: e, stackTrace: st);
      return false;
    }
  }
}
