import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../models/message.dart';
import 'encryption_service.dart';
import 'local_storage_service.dart';
import 'message_cache.dart';
import 'message_relay.dart';
import 'message_storage_interface.dart';
import 'offline_queue_service.dart';

/// DoD 5220.22-M recommended number of overwrite passes for secure deletion.
const int _defaultSecurePasses = 3;

/// Secure deletion and privacy cleanup. Ensures data is properly removed when users
/// delete conversations or log out.
///
/// - [secureDeleteMessage]: Firestore delete, then overwrite in Hive 3x (DoD 5220.22-M), then delete and verify.
/// - [secureDeleteConversation]: Secure-delete each message, overwrite key 3x, delete metadata and caches.
/// - [cleanupOnLogout]: Anonymous = full secure wipe + sign out; Admin = temp caches only, keep keys.
/// - [prepareForUninstall]: Optional Firestore wipe, write deletion_requests doc (7-day grace for Cloud Function).
/// - [exportUserData] / [deleteAllUserData]: GDPR export and right-to-be-forgotten.
///
/// **Logging:** Log that deletion or export occurred (e.g. "secure delete message completed"); never log content or keys.
class PrivacyService {
  PrivacyService({
    MessageRelay? relay,
    MessageServiceStorage? storage,
    EncryptionService? encryption,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    OfflineQueueService? offlineQueue,
    Logger? logger,
  })  : _relay = relay,
        _storage = storage ?? LocalStorageService.instance,
        _encryption = encryption ?? EncryptionService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _offlineQueue = offlineQueue,
        _log = logger ?? Logger();

  final MessageRelay? _relay;
  final MessageServiceStorage _storage;
  final EncryptionService _encryption;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final OfflineQueueService? _offlineQueue;
  final Logger _log;

  static const String _messagesCollection = 'messages';
  static const String _conversationsCollection = 'conversations';
  static const String _deletionRequestsCollection = 'deletion_requests';

  final Random _secureRandom = Random.secure();

  String _randomBase64([int length = 44]) {
    final bytes = List<int>.generate(length, (_) => _secureRandom.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '').padRight(length, 'A').substring(0, length);
  }

  String _randomString([int length = 256]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (_) => chars[_secureRandom.nextInt(chars.length)]).join();
  }

  /// Overwrites a message slot in Hive with random data [passes] times (DoD 5220.22-M), then deletes.
  Future<void> _secureOverwriteMessage(String messageId, int passes) async {
    final dummy = Message(
      id: messageId,
      conversationId: _randomString(16),
      senderId: _randomString(16),
      encryptedContent: _randomBase64(64),
      content: _randomString(128),
      timestamp: DateTime.now(),
      status: MessageStatus.unread,
      iv: List.generate(16, (_) => _secureRandom.nextInt(256)),
      preview: _randomString(32),
      senderType: 'anonymous',
    );
    for (var i = 0; i < passes; i++) {
      await _storage.storeMessage(dummy);
    }
    await _storage.deleteMessage(messageId);
  }

  /// Overwrites a conversation key slot in Hive with random data [passes] times, then deletes.
  Future<void> _secureOverwriteKey(String conversationId, int passes) async {
    for (var i = 0; i < passes; i++) {
      await _storage.storeConversationKey(conversationId, _randomBase64(44));
    }
    await _storage.deleteConversationKey(conversationId);
  }

  /// Securely deletes a single message: Firestore → overwrite in Hive 3x → delete → verify.
  Future<void> secureDeleteMessage(String messageId) async {
    if (messageId.isEmpty) return;
    try {
      if (_relay != null) {
        try {
          await _relay!.delete(messageId);
          _log.i('PrivacyService: secure delete message completed (Firestore)');
        } on Exception catch (e) {
          _log.w('PrivacyService: Firestore delete message failed (may be offline)', error: e);
        }
      }
      final existing = await _storage.getMessage(messageId);
      if (existing != null) {
        await _secureOverwriteMessage(messageId, _defaultSecurePasses);
        _log.i('PrivacyService: secure delete message completed (local overwrite and delete)');
      }
      final verify = await _storage.getMessage(messageId);
      if (verify != null) {
        _log.w('PrivacyService: verify after secure delete found message still present');
      }
    } catch (e, st) {
      _log.e('PrivacyService: secureDeleteMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Securely deletes a conversation: each message, then key (overwrite + delete), Firestore metadata, caches.
  Future<void> secureDeleteConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    try {
      final messages = await _storage.getConversationMessages(conversationId);
      for (final m in messages) {
        await secureDeleteMessage(m.id);
      }
      final key = await _storage.getConversationKey(conversationId);
      if (key != null && key.isNotEmpty) {
        await _secureOverwriteKey(conversationId, _defaultSecurePasses);
        await _encryption.deleteKey(conversationId);
        _log.i('PrivacyService: secure delete conversation key completed');
      }
      try {
        await _firestore.collection(_conversationsCollection).doc(conversationId).delete();
        _log.i('PrivacyService: conversation metadata deleted from Firestore');
      } on Exception catch (e) {
        _log.w('PrivacyService: Firestore conversation delete failed', error: e);
      }
      final pendingKey = 'message_service_pending_$conversationId';
      await _storage.setUserPref(pendingKey, '');
      if (_offlineQueue != null) {
        final pending = _offlineQueue!.getPendingMessages(conversationId);
        for (final p in pending) {
          await _offlineQueue!.removeFromQueue(p.id);
        }
      }
      try {
        await MessageCache.instance.clearConversationCache(conversationId);
      } catch (_) {}
      await _storage.deleteConversation(conversationId);
    } catch (e, st) {
      _log.e('PrivacyService: secureDeleteConversation failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Logout cleanup. Anonymous: full secure wipe of messages and keys, clear caches, sign out, clear queue. Admin: keep keys and metadata, clear temp caches only.
  Future<void> cleanupOnLogout({required bool isAnonymous}) async {
    try {
      final userIdBeforeSignOut = _auth.currentUser?.uid ?? '';
      if (isAnonymous) {
        final messageIds = await _storage.getAllMessageIds();
        final convKeys = await _storage.getAllConversationKeys();
        for (final mid in messageIds) {
          await _secureOverwriteMessage(mid, _defaultSecurePasses);
        }
        for (final cid in convKeys.keys) {
          await _secureOverwriteKey(cid, _defaultSecurePasses);
        }
        _offlineQueue?.clearQueue();
        await LocalStorageService.instance.clearAllData();
        _log.i('PrivacyService: anonymous logout cleanup completed (secure wipe)');
      } else {
        await _storage.setUserPref('message_service_pending_', '');
        _offlineQueue?.clearQueue();
        _log.i('PrivacyService: admin logout cleanup completed (temp caches only)');
      }
      await _auth.signOut();
      if (isAnonymous && userIdBeforeSignOut.isNotEmpty) {
        final verify = await verifyDataDeleted(userIdBeforeSignOut);
        if (!verify) _log.w('PrivacyService: post-logout verify reported data may remain');
      }
    } catch (e, st) {
      _log.e('PrivacyService: cleanupOnLogout failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Prepares for app uninstall: optional Firestore deletion, marks account for deletion (7-day grace).
  /// Backend: deploy a Cloud Function that reads [deletion_requests] and performs full deletion after 7 days.
  Future<void> prepareForUninstall({bool deleteSensitiveDataFromFirestore = false}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) return;
    try {
      if (deleteSensitiveDataFromFirestore) {
        final snapshot = await _firestore
            .collection(_messagesCollection)
            .where('senderId', isEqualTo: userId)
            .get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
        _log.i('PrivacyService: sensitive messages deleted from Firestore for user');
      }
      await _firestore.collection(_deletionRequestsCollection).doc(userId).set({
        'requestedAt': FieldValue.serverTimestamp(),
        'gracePeriodDays': 7,
      });
      _log.i('PrivacyService: deletion request recorded (7-day grace period)');
    } catch (e, st) {
      _log.e('PrivacyService: prepareForUninstall failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// GDPR: export all data associated with [userId]. Does not include encryption keys.
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final keys = await _storage.getAllConversationKeys();
    final conversations = <String, List<Map<String, dynamic>>>{};
    for (final conversationId in keys.keys) {
      final messages = await _storage.getConversationMessages(conversationId);
      conversations[conversationId] = messages
          .where((m) => m.senderId == userId)
          .map((m) => {
                'id': m.id,
                'conversationId': m.conversationId,
                'timestamp': m.timestamp.toIso8601String(),
                'content': m.content,
                'status': m.status.value,
              })
          .toList();
    }
    return {
      'userId': userId,
      'exportedAt': DateTime.now().toIso8601String(),
      'conversations': conversations,
    };
  }

  /// GDPR right to be forgotten: delete all user data (Firestore messages sent by user, local data if current user).
  Future<void> deleteAllUserData(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .where('senderId', isEqualTo: userId)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      _log.i('PrivacyService: Firestore messages deleted for user (GDPR)');
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == userId) {
        await cleanupOnLogout(isAnonymous: _auth.currentUser?.isAnonymous ?? true);
      }
    } catch (e, st) {
      _log.e('PrivacyService: deleteAllUserData failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Verifies no data remains for [userId]. Checks Firestore and local storage.
  Future<bool> verifyDataDeleted(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .where('senderId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return false;
      final keys = await _storage.getAllConversationKeys();
      if (keys.isNotEmpty) return false;
      final allIds = await _storage.getAllMessageIds();
      for (final id in allIds) {
        final m = await _storage.getMessage(id);
        if (m != null && m.senderId == userId) return false;
      }
      return true;
    } catch (e, st) {
      _log.e('PrivacyService: verifyDataDeleted failed', error: e, stackTrace: st);
      return false;
    }
  }
}
