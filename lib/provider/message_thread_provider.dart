import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_message.dart';
import '../models/synced_message.dart';
import '../services/message_sync_service.dart';

/// Typing state for the thread (who is currently typing).
class ThreadTypingState {
  const ThreadTypingState({this.adminTyping = false, this.anonymousTyping = false});

  final bool adminTyping;
  final bool anonymousTyping;

  bool get anyoneTyping => adminTyping || anonymousTyping;
}

/// Provides real-time messages and typing for a single conversation thread.
/// When [syncService] is provided, messages use offline queue, cache, and sync status.
class MessageThreadProvider extends ChangeNotifier {
  MessageThreadProvider({
    required FirebaseFirestore firestore,
    required this.conversationId,
    required this.currentUserIsAdmin,
    this.currentAdminUid,
    MessageSyncService? syncService,
  })  : _firestore = firestore,
        _syncService = syncService;

  final FirebaseFirestore _firestore;
  final MessageSyncService? _syncService;
  final String conversationId;
  final bool currentUserIsAdmin;
  final String? currentAdminUid;

  List<AdminMessage> _messages = [];
  List<AdminMessage> get messages => List.unmodifiable(_messages);

  List<SyncedMessage> _syncedMessages = [];
  /// When [syncService] is used, this is set so UI can show [SyncStatusBadge].
  List<SyncedMessage> get syncedMessages =>
      _syncService != null ? List.unmodifiable(_syncedMessages) : const [];

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;
  bool get hasError => _error != null;

  bool _sending = false;
  bool get sending => _sending;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  ThreadTypingState _typing = const ThreadTypingState();
  ThreadTypingState get typing => _typing;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messageSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _typingSub;
  StreamSubscription<List<SyncedMessage>>? _syncMessageSub;
  StreamSubscription<bool>? _connectivitySub;

  static const int _maxChars = 500;

  int get maxCharacters => _maxChars;

  CollectionReference<Map<String, dynamic>> get _messagesCol =>
      _firestore.collection('messages').withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
            toFirestore: (v, _) => v,
          );

  DocumentReference<Map<String, dynamic>> get _typingDoc =>
      _firestore.collection('conversations').doc(conversationId).withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
            toFirestore: (v, _) => v,
          );

  /// Start listening to messages and typing for this conversation.
  void startListening() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _syncMessageSub?.cancel();
    _connectivitySub?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (_syncService != null) {
      _syncMessageSub = _syncService!.watchConversation(conversationId).listen(
            (list) {
              _syncedMessages = list;
              _messages = list.map((s) => s.message).toList();
              _isLoading = false;
              _error = null;
              notifyListeners();
            },
            onError: (e, st) {
              _error = e;
              _isLoading = false;
              notifyListeners();
            },
          );
      _connectivitySub = _syncService!.connectivityStream.listen((online) {
        _isOffline = !online;
        notifyListeners();
      });
    } else {
      _messageSub = _messagesCol
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen(
            (snapshot) {
              _messages = snapshot.docs
                  .map((d) => AdminMessage.fromFirestoreWithSenderType(d, currentAdminUid))
                  .toList();
              _isLoading = false;
              _error = null;
              notifyListeners();
            },
            onError: (e, st) {
              _error = e;
              _isLoading = false;
              notifyListeners();
            },
          );
    }

    _typingSub = _typingDoc.snapshots().listen((snapshot) {
      final data = snapshot.data() ?? {};
      final admin = data['typingAdmin'] as bool? ?? false;
      final anon = data['typingAnonymous'] as bool? ?? false;
      _typing = ThreadTypingState(adminTyping: admin, anonymousTyping: anon);
      notifyListeners();
    });
  }

  /// Send a new message. [plainText] is the content; caller is responsible for
  /// encrypting and setting [encryptedContent] / [iv] if using E2E.
  Future<void> sendMessage({
    required String plainText,
    String? encryptedContent,
    List<int>? iv,
  }) async {
    if (plainText.trim().isEmpty) return;
    _sending = true;
    notifyListeners();

    try {
      final content = plainText.trim();
      final enc = encryptedContent ?? content;
      final preview = content.length > 100 ? '${content.substring(0, 100)}…' : content;

      if (_syncService != null) {
        await _syncService!.sendMessage(
          conversationId: conversationId,
          encryptedContent: enc,
          preview: preview,
          iv: iv,
        );
      } else {
        final ref = _messagesCol.doc();
        final msg = {
          'conversationId': conversationId,
          'senderId': currentAdminUid ?? _firestore.collection('administrators').doc().id,
          'senderType': currentUserIsAdmin ? 'admin' : 'anonymous',
          'encryptedContent': enc,
          'preview': preview,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'unread',
          if (iv != null) 'iv': iv,
        };
        await ref.set(msg);
      }
      await _clearTyping();
    } catch (e) {
      _error = e;
      notifyListeners();
      rethrow;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> _clearTyping() async {
    try {
      if (currentUserIsAdmin) {
        await _typingDoc.set({'typingAdmin': false}, SetOptions(merge: true));
      } else {
        await _typingDoc.set({'typingAnonymous': false}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Retry sending a failed/pending message (e.g. user tapped Retry). [messageId] is the local id for pending messages.
  Future<void> retryFailedMessage(String messageId) async {
    if (_syncService == null) return;
    await _syncService!.retryPendingMessage(messageId);
    notifyListeners();
  }

  /// Call when the user is typing. Throttle in UI (e.g. every 1s).
  Future<void> setTyping(bool isTyping) async {
    try {
      if (currentUserIsAdmin) {
        await _typingDoc.set({'typingAdmin': isTyping}, SetOptions(merge: true));
      } else {
        await _typingDoc.set({'typingAnonymous': isTyping}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({'status': 'read'});
    } catch (_) {}
  }

  void stopListening() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _syncMessageSub?.cancel();
    _connectivitySub?.cancel();
    _messageSub = null;
    _typingSub = null;
    _syncMessageSub = null;
    _connectivitySub = null;
  }

  @override
  void dispose() {
    stopListening();
    _syncService?.dispose();
    super.dispose();
  }
}
