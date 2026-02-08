import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

import '../models/pending_message.dart';
import 'local_storage_service.dart';
import 'message_relay.dart';
import 'message_storage_interface.dart';
import 'network_service.dart';

/// Exponential backoff delays in seconds: 1, 2, 4, 8, 16, cap 60.
const List<int> _backoffSeconds = [1, 2, 4, 8, 16, 60];
const int _maxRetries = 5;

/// Backoff in seconds: 1st retry 1s, 2nd 2s, 3rd 4s, 4th 8s, 5th 16s, then 60s. [attemptNumber] is 1-based.
int _backoffSecondsForAttempt(int attemptNumber) {
  final idx = (attemptNumber - 1).clamp(0, _backoffSeconds.length - 1);
  return _backoffSeconds[idx];
}

/// Offline message queue: store messages in Hive when offline, sync when connection returns.
/// Uses [NetworkService] to detect connectivity and triggers [processQueue] when online.
class OfflineQueueService {
  OfflineQueueService({
    MessageRelay? relay,
    MessageServiceStorage? storage,
    NetworkService? networkService,
    Logger? logger,
    /// For tests: inject an already-open box to avoid Hive init.
    Box<PendingMessage>? pendingBox,
  })  : _relay = relay,
        _storage = storage ?? LocalStorageService.instance,
        _network = networkService ?? NetworkService(logger: logger),
        _log = logger ?? Logger(),
        _box = pendingBox;

  final MessageRelay? _relay;
  final MessageServiceStorage _storage;
  final NetworkService _network;
  final Logger _log;

  static const String _boxName = 'pending_messages';

  Box<PendingMessage>? _box;
  StreamSubscription<bool>? _connectivitySub;
  bool _processing = false;

  /// Ensures Hive is inited (via [LocalStorageService]) and opens the pending_messages box.
  /// No-op if a [pendingBox] was provided to the constructor (e.g. in tests).
  Future<void> init() async {
    if (_box != null) return;
    await LocalStorageService.instance.init();
    _box = await Hive.openBox<PendingMessage>(_boxName);
    _log.d('OfflineQueueService: opened box $_boxName');
  }

  Box<PendingMessage> get _pending {
    final b = _box;
    if (b == null) throw StateError('OfflineQueueService not initialized. Call init() first.');
    return b;
  }

  /// Adds a message to the queue (e.g. when offline or send failed).
  Future<void> queueMessage(PendingMessage message) async {
    await init();
    await _pending.put(message.id, message);
    _log.d('OfflineQueueService: queued message ${message.id}');
  }

  /// Processes the queue: sends pending/failed messages (with retry limit and backoff).
  /// Call when online. Uses exponential backoff; max [_maxRetries] attempts per message.
  Future<void> processQueue() async {
    if (_relay == null) {
      _log.w('OfflineQueueService: no relay, skip processQueue');
      return;
    }
    if (_processing) return;
    _processing = true;
    try {
      await init();
      final now = DateTime.now();
      final candidates = _pending.values.where((p) {
        if (p.status == PendingMessageStatus.sent) return false;
        if (p.retryCount >= _maxRetries) return false;
        if (p.nextRetryAt != null && now.isBefore(p.nextRetryAt!)) return false;
        return true;
      }).toList();
      candidates.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (final pending in candidates) {
        await _pending.put(pending.id, pending.copyWith(status: PendingMessageStatus.sending));
        try {
          final data = {
            'conversationId': pending.conversationId,
            'senderId': pending.senderId,
            'senderType': pending.senderType ?? 'anonymous',
            'encryptedContent': pending.encryptedContent,
            'iv': pending.iv,
            'preview': pending.preview,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'unread',
          };
          final serverId = await _relay!.add(data);
          await _storage.updateMessageId(pending.id, serverId);
          await removeFromQueue(pending.id);
          _log.d('OfflineQueueService: sent queued message ${pending.id} -> $serverId');
        } catch (e, st) {
          _log.w('OfflineQueueService: send failed for ${pending.id}', error: e, stackTrace: st);
          final nextCount = pending.retryCount + 1;
          final delaySecs = _backoffSecondsForAttempt(nextCount);
          final nextRetryAt = DateTime.now().add(Duration(seconds: delaySecs));
          await _pending.put(
            pending.id,
            pending.copyWith(
              status: PendingMessageStatus.failed,
              retryCount: nextCount,
              lastError: e.toString(),
              nextRetryAt: nextRetryAt,
            ),
          );
          if (nextCount >= _maxRetries) {
            _log.w('OfflineQueueService: message ${pending.id} permanently failed after $nextCount attempts');
          }
        }
      }
    } finally {
      _processing = false;
    }
  }

  /// Returns pending messages for [conversationId], sorted by timestamp.
  List<PendingMessage> getPendingMessages(String conversationId) {
    if (_box == null) return [];
    final list = _pending.values
        .where((p) => p.conversationId == conversationId)
        .toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  /// Removes a message from the queue after successful send.
  Future<void> removeFromQueue(String messageId) async {
    await init();
    await _pending.delete(messageId);
    _log.d('OfflineQueueService: removed from queue $messageId');
  }

  /// Marks a message as failed (e.g. for UI). Optionally increments retry count.
  Future<void> markAsFailed(String messageId, String error) async {
    await init();
    final p = _pending.get(messageId);
    if (p == null) return;
    await _pending.put(
      messageId,
      p.copyWith(
        status: PendingMessageStatus.failed,
        lastError: error,
        retryCount: p.retryCount + 1,
      ),
    );
    _log.d('OfflineQueueService: marked failed $messageId');
  }

  /// Clears the entire queue (e.g. on logout).
  Future<void> clearQueue() async {
    if (_box == null) return;
    await _pending.clear();
    _log.d('OfflineQueueService: queue cleared');
  }

  /// Starts listening to connectivity and calls [processQueue] when online.
  void startConnectivityMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = _network.onConnectivityChanged.listen((connected) {
      if (connected) {
        _log.d('OfflineQueueService: connection restored, processing queue');
        processQueue();
      }
    });
  }

  /// Stops connectivity monitoring.
  void stopConnectivityMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
