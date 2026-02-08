import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_message.dart';

/// Typing state for the thread (who is currently typing).
class ThreadTypingState {
  const ThreadTypingState({this.adminTyping = false, this.anonymousTyping = false});

  final bool adminTyping;
  final bool anonymousTyping;

  bool get anyoneTyping => adminTyping || anonymousTyping;
}

/// Provides real-time messages and typing for a single conversation thread.
class MessageThreadProvider extends ChangeNotifier {
  MessageThreadProvider({
    required FirebaseFirestore firestore,
    required this.conversationId,
    required this.currentUserIsAdmin,
    this.currentAdminUid,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final String conversationId;
  final bool currentUserIsAdmin;
  final String? currentAdminUid;

  List<AdminMessage> _messages = [];
  List<AdminMessage> get messages => List.unmodifiable(_messages);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;
  bool get hasError => _error != null;

  bool _sending = false;
  bool get sending => _sending;

  ThreadTypingState _typing = const ThreadTypingState();
  ThreadTypingState get typing => _typing;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messageSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _typingSub;

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
    _isLoading = true;
    _error = null;
    notifyListeners();

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
      final ref = _messagesCol.doc();
      final msg = {
        'conversationId': conversationId,
        'senderId': currentAdminUid ?? _firestore.collection('administrators').doc().id,
        'senderType': currentUserIsAdmin ? 'admin' : 'anonymous',
        'encryptedContent': enc,
        'preview': content.length > 100 ? '${content.substring(0, 100)}…' : content,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
        if (iv != null) 'iv': iv,
      };
      await ref.set(msg);
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
    _messageSub = null;
    _typingSub = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
