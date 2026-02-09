import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/admin_message.dart';
import '../models/sync_status.dart';
import '../models/synced_message.dart';
import 'message_cache.dart';

/// Result of sending a message (queued or sent).
class SendResult {
  const SendResult({required this.syncedMessage, this.queued = false});
  final SyncedMessage syncedMessage;
  final bool queued;
}

/// Real-time message sync with offline queue, cache, and connectivity monitoring.
class MessageSyncService {
  MessageSyncService({
    required FirebaseFirestore firestore,
    required String currentUserId,
    bool Function()? isAdmin,
    MessageCache? cache,
  })  : _firestore = firestore,
        _currentUserId = currentUserId,
        _isAdmin = isAdmin ?? (() => true),
        _cache = cache ?? MessageCache.instance;

  final FirebaseFirestore _firestore;
  final String _currentUserId;
  final bool Function() _isAdmin;
  final MessageCache _cache;

  static const int _maxRetries = 8;
  static const int _initialBackoffMs = 1000;
  static const int _maxBackoffMs = 300000; // 5 min

  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  final StreamController<void> _pendingChangedController = StreamController<void>.broadcast();
  Stream<void> get pendingChanged => _pendingChangedController.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _conversationSubs = {};

  bool _initialized = false;
  Future<void> init() async {
    if (_initialized) return;
    await _cache.init();
    _initialized = true;
    _startConnectivityMonitoring();
    connectivityStream.first.then((_) {});
  }

  void _startConnectivityMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      if (wasOnline && !_isOnline) {
        _connectivityController.add(false);
      } else if (!wasOnline && _isOnline) {
        _connectivityController.add(true);
        syncPendingMessages();
      }
    });
    Connectivity().checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      _connectivityController.add(_isOnline);
    });
  }

  List<SyncedMessage> _mergedForConversation(String conversationId, List<SyncedMessage> server) {
    final pendingIds = _cache.getPendingLocalIds(conversationId);
    final pendingList = <SyncedMessage>[];
    for (final lid in pendingIds) {
      final m = _cache.getPending(lid);
      if (m != null) {
        try {
          pendingList.add(SyncedMessage.fromPendingMap(m, lid));
        } catch (_) {}
      }
    }
    return _merge(server, pendingList);
  }

  /// Watch messages for a conversation: merges Firestore stream + cached + pending, with offline support.
  Stream<List<SyncedMessage>> watchConversation(String conversationId) async* {
    await init();
    List<SyncedMessage> lastServer = [];
    final pendingIds = _cache.getPendingLocalIds(conversationId);
    final pending = <SyncedMessage>[];
    for (final lid in pendingIds) {
      final m = _cache.getPending(lid);
      if (m != null) {
        try {
          pending.add(SyncedMessage.fromPendingMap(m, lid));
        } catch (_) {}
      }
    }
    final cached = _cache.getCachedMessages(conversationId);
    final fromCache = cached.map((m) => _mapToSynced(m)).whereType<SyncedMessage>().toList();
    lastServer = fromCache;
    yield _merge(fromCache, pending);

    final stream = _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots();

    final outputController = StreamController<List<SyncedMessage>>.broadcast();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? firestoreSub;
    StreamSubscription<void>? pendingSub;
    void emitMerged() {
      if (!outputController.isClosed) {
        outputController.add(_mergedForConversation(conversationId, lastServer));
      }
    }
    pendingSub = _pendingChangedController.stream.listen((_) {
      emitMerged();
    });

    firestoreSub = stream.listen(
      (snapshot) {
        lastServer = snapshot.docs
            .map((d) => SyncedMessage.fromFirestore(d, _isAdmin() ? _currentUserId : null))
            .toList();
        final payloads = snapshot.docs.map((d) => _docToCacheMap(d)).toList();
        unawaited(_cache.setCachedMessages(conversationId, payloads));
        emitMerged();
      },
      onError: outputController.addError,
      onDone: () {
        pendingSub?.cancel();
        outputController.close();
      },
      cancelOnError: false,
    );

    try {
      yield* outputController.stream;
    } finally {
      await firestoreSub.cancel();
      await pendingSub?.cancel();
      if (!outputController.isClosed) outputController.close();
    }
  }

  List<SyncedMessage> _merge(List<SyncedMessage> server, List<SyncedMessage> pending) {
    final byTime = <SyncedMessage>[];
    byTime.addAll(server);
    byTime.addAll(pending.where((p) => !server.any((s) => s.id == p.localId)));
    byTime.sort((a, b) => a.message.timestamp.compareTo(b.message.timestamp));
    return byTime;
  }

  SyncedMessage? _mapToSynced(Map<String, dynamic> m) {
    try {
      final ts = m['timestamp'];
      DateTime dateTime = DateTime.now();
      if (ts is int) dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
      final msg = AdminMessage(
        id: m['id'] as String? ?? '',
        conversationId: m['conversationId'] as String? ?? '',
        senderId: m['senderId'] as String? ?? '',
        encryptedContent: m['encryptedContent'] as String? ?? '',
        timestamp: dateTime,
        status: MessageStatusX.fromString(m['status'] as String?),
        iv: (m['iv'] as List<dynamic>?)?.cast<int>(),
        preview: m['preview'] as String?,
        senderType: m['senderType'] as String?,
      );
      return SyncedMessage(message: msg, syncStatus: SyncStatus.sent);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _docToCacheMap(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final m = Map<String, dynamic>.from(data);
    m['id'] = d.id;
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      m['timestamp'] = ts.millisecondsSinceEpoch;
    }
    return m;
  }

  /// Send a message. If offline, queues and returns with [SendResult.queued] true.
  Future<SendResult> sendMessage({
    required String conversationId,
    required String encryptedContent,
    String? preview,
    List<int>? iv,
  }) async {
    await init();
    final localId = const Uuid().v4();
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'conversationId': conversationId,
      'senderId': _currentUserId,
      'encryptedContent': encryptedContent,
      'preview': preview ?? (encryptedContent.length > 100 ? '${encryptedContent.substring(0, 100)}…' : encryptedContent),
      'timestamp': now.millisecondsSinceEpoch,
      'status': 'unread',
      'senderType': _isAdmin() ? 'admin' : 'anonymous',
      if (iv != null && iv.isNotEmpty) 'iv': iv,
    };
    final synced = SyncedMessage(
      message: AdminMessage(
        id: localId,
        conversationId: conversationId,
        senderId: _currentUserId,
        encryptedContent: encryptedContent,
        timestamp: now,
        status: MessageStatus.unread,
        iv: iv,
        preview: payload['preview'] as String?,
        senderType: payload['senderType'] as String?,
      ),
      syncStatus: SyncStatus.sending,
      localId: localId,
    );

    if (!_isOnline) {
      await _cache.addPending(localId, payload);
      return SendResult(syncedMessage: synced, queued: true);
    }

    try {
      final ref = _firestore.collection('messages').doc();
      final firestorePayload = {
        ...payload,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await ref.set(firestorePayload);
    await _cache.removePending(localId);
    _pendingChangedController.add(null);
    return SendResult(syncedMessage: synced.copyWith(syncStatus: SyncStatus.sent));
    } catch (e) {
      await _cache.addPending(localId, payload);
      _pendingChangedController.add(null);
      return SendResult(
        syncedMessage: synced.copyWith(syncStatus: SyncStatus.failed),
        queued: true,
      );
    }
  }

  /// Retry sending a single pending message (e.g. user tapped Retry). Notifies stream to refresh.
  Future<void> retryPendingMessage(String localId) async {
    await init();
    final data = _cache.getPending(localId);
    if (data == null) return;
    await _trySendPending(localId, Map<String, dynamic>.from(data));
    _pendingChangedController.add(null);
  }

  /// Call when connectivity is restored to flush the pending queue with exponential backoff.
  Future<void> syncPendingMessages() async {
    await init();
    final ids = _cache.getAllPendingIds();
    for (final localId in ids) {
      final data = _cache.getPending(localId);
      if (data == null) continue;
      await _trySendPending(localId, Map<String, dynamic>.from(data));
    }
    await _cache.clearOldPending();
    await _cache.clearOldCache();
  }

  Future<void> _trySendPending(String localId, Map<String, dynamic> payload) async {
    final retryCount = (payload['retryCount'] as num?)?.toInt() ?? 0;
    if (retryCount >= _maxRetries) {
      await _cache.updatePending(localId, {'syncStatus': 'failed'});
      return;
    }
    final backoffMs = (_initialBackoffMs * (1 << retryCount)).clamp(_initialBackoffMs, _maxBackoffMs);
    final nextRetryAt = (payload['nextRetryAt'] as num?)?.toInt() ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < nextRetryAt) return;

    try {
      final ref = _firestore.collection('messages').doc();
      final firestorePayload = <String, dynamic>{
        'conversationId': payload['conversationId'],
        'senderId': payload['senderId'],
        'encryptedContent': payload['encryptedContent'],
        'preview': payload['preview'],
        'timestamp': FieldValue.serverTimestamp(),
        'status': payload['status'] ?? 'unread',
        'senderType': payload['senderType'],
      };
      if (payload['iv'] != null) firestorePayload['iv'] = payload['iv'];
      await ref.set(firestorePayload);
      await _cache.removePending(localId);
      _pendingChangedController.add(null);
    } catch (e) {
      await _cache.updatePending(localId, {
        'retryCount': retryCount + 1,
        'nextRetryAt': DateTime.now().millisecondsSinceEpoch + backoffMs,
        'syncStatus': 'failed',
      });
      _pendingChangedController.add(null);
      if (retryCount + 1 < _maxRetries) {
        Future.delayed(Duration(milliseconds: backoffMs), () => _trySendPending(localId, payload));
      }
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    for (final sub in _conversationSubs.values) {
      sub.cancel();
    }
    _conversationSubs.clear();
    _connectivityController.close();
  }
}

void unawaited(Future<void> f) {}