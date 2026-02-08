import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/synced_message.dart';
import '../services/message_sync_service.dart';

/// Exposes [MessageSyncService] for UI: watch messages with offline support, send with queue, connectivity.
class MessageSyncProvider extends ChangeNotifier {
  MessageSyncProvider({
    required FirebaseFirestore firestore,
    String? currentUserId,
    MessageSyncService? syncService,
  })  : _firestore = firestore,
        _syncService = syncService ??
            MessageSyncService(
              firestore: firestore,
              currentUserId: currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
              isAdmin: () => !(FirebaseAuth.instance.currentUser?.isAnonymous ?? true),
            );

  final FirebaseFirestore _firestore;
  final MessageSyncService _syncService;

  List<SyncedMessage> _messages = [];
  List<SyncedMessage> get messages => List.unmodifiable(_messages);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  Object? _error;
  Object? get error => _error;
  bool get hasError => _error != null;

  bool _sending = false;
  bool get sending => _sending;

  StreamSubscription<List<SyncedMessage>>? _messageSub;
  StreamSubscription<bool>? _connectivitySub;

  String? _conversationId;

  bool get isOnline => !_isOffline;

  /// Start watching [conversationId]. Call when opening the thread.
  void startWatching(String conversationId) {
    if (_conversationId == conversationId) return;
    stopWatching();
    _conversationId = conversationId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _messageSub = _syncService.watchConversation(conversationId).listen(
          (list) {
            _messages = list;
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

    _connectivitySub = _syncService.connectivityStream.listen((online) {
      _isOffline = !online;
      notifyListeners();
    });
  }

  void stopWatching() {
    _messageSub?.cancel();
    _connectivitySub?.cancel();
    _messageSub = null;
    _connectivitySub = null;
    _conversationId = null;
  }

  /// Send a message (queued if offline). Returns the [SyncedMessage] for optimistic UI.
  Future<SendResult> sendMessage({
    required String conversationId,
    required String encryptedContent,
    String? preview,
    List<int>? iv,
  }) async {
    _sending = true;
    notifyListeners();
    try {
      final result = await _syncService.sendMessage(
        conversationId: conversationId,
        encryptedContent: encryptedContent,
        preview: preview,
        iv: iv,
      );
      _sending = false;
      notifyListeners();
      return result;
    } catch (e) {
      _sending = false;
      _error = e;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    stopWatching();
    _syncService.dispose();
    super.dispose();
  }
}
