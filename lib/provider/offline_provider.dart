import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/admin_message.dart';
import '../models/conversation.dart';
import '../services/offline_service.dart';

/// Exposes [OfflineService] state for UI: online/offline, syncing, pending count, retry.
class OfflineProvider extends ChangeNotifier with WidgetsBindingObserver {
  OfflineProvider({
    required FirebaseFirestore firestore,
    String? currentUserId,
    OfflineService? offlineService,
  })  : _firestore = firestore,
        _offlineService = offlineService ??
            OfflineService(
              firestore: firestore,
              currentUserId: currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
            );

  final FirebaseFirestore _firestore;
  final OfflineService _offlineService;

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  int _failedCount = 0;
  int get failedCount => _failedCount;

  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<bool>? _syncingSub;
  StreamSubscription<int>? _pendingSub;

  bool _initialized = false;
  Future<void> init() async {
    if (_initialized) return;
    await _offlineService.init();
    _initialized = true;
    _onlineSub = _offlineService.isOnlineStream.listen((online) {
      _isOnline = online;
      notifyListeners();
    });
    _syncingSub = _offlineService.isSyncingStream.listen((syncing) {
      _isSyncing = syncing;
      notifyListeners();
    });
    _pendingSub = _offlineService.pendingCountStream.listen((count) {
      _pendingCount = count;
      _failedCount = 0;
      _offlineService.getPendingOperations().then((ops) {
        _failedCount = ops.where((o) => o.isFailed).length;
        notifyListeners();
      });
      notifyListeners();
    });
    _offlineService.getPendingOperations().then((ops) {
      _pendingCount = ops.length;
      _failedCount = ops.where((o) => o.isFailed).length;
      notifyListeners();
    });
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _offlineService.syncWhenOnline();
    }
  }

  Future<void> cacheMessage(AdminMessage message) => _offlineService.cacheMessage(message);
  Future<void> cacheMessages(String conversationId, List<AdminMessage> messages) =>
      _offlineService.cacheMessages(conversationId, messages);
  Future<CachedConversation> getCachedConversation(String id) =>
      _offlineService.getCachedConversation(id);
  Future<void> cacheConversation(Conversation c) => _offlineService.cacheConversation(c);
  Future<int> queueOperation(String type, Map<String, dynamic> payload) =>
      _offlineService.queueOperation(type, payload);
  Future<void> syncWhenOnline() => _offlineService.syncWhenOnline();
  Future<void> retryOperation(int opId) => _offlineService.retryOperation(opId);
  Future<void> retryAllFailed() => _offlineService.retryAllFailed();
  Future<List<PendingOperation>> getPendingOperations() => _offlineService.getPendingOperations();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineSub?.cancel();
    _syncingSub?.cancel();
    _pendingSub?.cancel();
    _offlineService.dispose();
    super.dispose();
  }
}
