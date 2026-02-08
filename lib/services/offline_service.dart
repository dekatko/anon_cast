import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/admin_message.dart';
import '../models/conversation.dart';

/// Result of loading a conversation from cache (messages + optional conversation meta).
class CachedConversation {
  const CachedConversation({
    required this.messages,
    this.conversation,
  });
  final List<AdminMessage> messages;
  final Conversation? conversation;
}

/// One queued operation (send message, update status, etc.).
class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    required this.status,
  });
  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final String status;

  bool get isPending => status == kOpStatusPending || status == kOpStatusFailed;
  bool get isFailed => status == kOpStatusFailed;
}

/// Central offline support: local DB (sqflite), connectivity, queue, and sync.
/// Call [init] once (e.g. at app start). Listen to [isOnlineStream] for UI.
class OfflineService {
  OfflineService({
    required FirebaseFirestore firestore,
    required String currentUserId,
    AppDatabase? database,
  })  : _firestore = firestore,
        _currentUserId = currentUserId,
        _db = database ?? AppDatabase.instance;

  final FirebaseFirestore _firestore;
  final String _currentUserId;
  final AppDatabase _db;

  final StreamController<bool> _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get isOnlineStream => _onlineController.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _initialized = false;
  bool _syncing = false;
  final StreamController<bool> _syncingController = StreamController<bool>.broadcast();
  Stream<bool> get isSyncingStream => _syncingController.stream;
  bool get isSyncing => _syncing;

  final StreamController<int> _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Initialize DB and start connectivity monitoring. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    await _db.init();
    _initialized = true;
    _startConnectivityMonitoring();
    _onlineController.add(_isOnline);
    unawaited(_broadcastPendingCount());
  }

  void _startConnectivityMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final nowOnline = results.any((r) => r != ConnectivityResult.none);
      if (_isOnline != nowOnline) {
        _isOnline = nowOnline;
        _onlineController.add(_isOnline);
        if (_isOnline) unawaited(syncWhenOnline());
      }
    });
    Connectivity().checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      _onlineController.add(_isOnline);
    });
  }

  /// Cache a message locally (from server or optimistic).
  Future<void> cacheMessage(AdminMessage message) async {
    await _db.ready;
    final db = _db.db;
    final ivBlob = message.iv != null ? _encodeIv(message.iv!) : null;
    await db.insert(
      kTableMessages,
      {
        kColId: message.id,
        kColConversationId: message.conversationId,
        kColSenderId: message.senderId,
        kColEncryptedContent: message.encryptedContent,
        kColTimestamp: message.timestamp.millisecondsSinceEpoch,
        kColStatus: message.status.value,
        kColIv: ivBlob,
        kColPreview: message.preview,
        kColSenderType: message.senderType,
        kColSyncedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cache multiple messages for a conversation (e.g. after fetching from server).
  Future<void> cacheMessages(String conversationId, List<AdminMessage> messages) async {
    await _db.ready;
    final batch = _db.db.batch();
    for (final m in messages) {
      final ivBlob = m.iv != null ? _encodeIv(m.iv!) : null;
      batch.insert(
        kTableMessages,
        {
          kColId: m.id,
          kColConversationId: m.conversationId,
          kColSenderId: m.senderId,
          kColEncryptedContent: m.encryptedContent,
          kColTimestamp: m.timestamp.millisecondsSinceEpoch,
          kColStatus: m.status.value,
          kColIv: ivBlob,
          kColPreview: m.preview,
          kColSenderType: m.senderType,
          kColSyncedAt: DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  List<int> _encodeIv(List<int> iv) => iv;
  List<int>? _decodeIv(dynamic v) {
    if (v == null) return null;
    if (v is List) return v.cast<int>();
    if (v is Uint8List) return v.toList();
    return null;
  }

  /// Get a conversation and its messages from local cache.
  Future<CachedConversation> getCachedConversation(String conversationId) async {
    await _db.ready;
    final db = _db.db;
    final msgRows = await db.query(
      kTableMessages,
      where: '$kColConversationId = ?',
      whereArgs: [conversationId],
      orderBy: '$kColTimestamp ASC',
    );
    final messages = msgRows.map((r) => _rowToMessage(r)).toList();
    final convRows = await db.query(
      kTableConversations,
      where: '$kColId = ?',
      whereArgs: [conversationId],
    );
    Conversation? conv;
    if (convRows.isNotEmpty) {
      conv = _rowToConversation(convRows.first);
    }
    return CachedConversation(messages: messages, conversation: conv);
  }

  AdminMessage _rowToMessage(Map<String, dynamic> r) {
    final ts = r[kColTimestamp] as int? ?? 0;
    final iv = _decodeIv(r[kColIv]);
    return AdminMessage(
      id: r[kColId] as String? ?? '',
      conversationId: r[kColConversationId] as String? ?? '',
      senderId: r[kColSenderId] as String? ?? '',
      encryptedContent: r[kColEncryptedContent] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      status: MessageStatusX.fromString(r[kColStatus] as String?),
      iv: iv,
      preview: r[kColPreview] as String?,
      senderType: r[kColSenderType] as String?,
    );
  }

  Conversation _rowToConversation(Map<String, dynamic> r) {
    return Conversation(
      id: r[kColId] as String? ?? '',
      organizationId: r[kColOrganizationId] as String? ?? '',
      adminId: r[kColAdminId] as String? ?? '',
      anonymousUserId: r[kColAnonymousUserId] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(r[kColCreatedAt] as int? ?? 0),
      updatedAt: _msToDate(r[kColUpdatedAt]),
      lastMessageAt: _msToDate(r[kColLastMessageAt]),
      typingAdmin: (r[kColTypingAdmin] as int?) == 1,
      typingAnonymous: (r[kColTypingAnonymous] as int?) == 1,
    );
  }

  DateTime? _msToDate(dynamic v) {
    if (v == null) return null;
    final n = v is int ? v : (v as num?)?.toInt();
    if (n == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(n);
  }

  /// Cache conversation metadata.
  Future<void> cacheConversation(Conversation c) async {
    await _db.ready;
    await _db.db.insert(
      kTableConversations,
      {
        kColId: c.id,
        kColOrganizationId: c.organizationId,
        kColAdminId: c.adminId,
        kColAnonymousUserId: c.anonymousUserId,
        kColCreatedAt: c.createdAt.millisecondsSinceEpoch,
        kColUpdatedAt: c.updatedAt?.millisecondsSinceEpoch,
        kColLastMessageAt: c.lastMessageAt?.millisecondsSinceEpoch,
        kColTypingAdmin: c.typingAdmin == true ? 1 : 0,
        kColTypingAnonymous: c.typingAnonymous == true ? 1 : 0,
        kColSyncedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Queue an operation to run when online (e.g. send_message, update_message_status).
  Future<int> queueOperation(String type, Map<String, dynamic> payload) async {
    await _db.ready;
    final id = await _db.db.insert(kTablePendingOps, {
      kColOpType: type,
      kColPayload: jsonEncode(payload),
      kColCreatedAtOp: DateTime.now().millisecondsSinceEpoch,
      kColRetryCount: 0,
      kColOpStatus: kOpStatusPending,
    });
    await _broadcastPendingCount();
    return id;
  }

  /// List pending operations (for UI / retry).
  Future<List<PendingOperation>> getPendingOperations() async {
    await _db.ready;
    final rows = await _db.db.query(
      kTablePendingOps,
      where: '$kColOpStatus = ? OR $kColOpStatus = ?',
      whereArgs: [kOpStatusPending, kOpStatusFailed],
      orderBy: '$kColCreatedAtOp ASC',
    );
    return rows.map(_rowToPendingOp).toList();
  }

  PendingOperation _rowToPendingOp(Map<String, dynamic> r) {
    final payloadJson = r[kColPayload] as String? ?? '{}';
    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(payloadJson) as Map);
    } catch (_) {
      payload = {};
    }
    final createdAt = r[kColCreatedAtOp] as int? ?? 0;
    return PendingOperation(
      id: r[kColOpId] as int? ?? 0,
      type: r[kColOpType] as String? ?? '',
      payload: payload,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      retryCount: r[kColRetryCount] as int? ?? 0,
      lastError: r[kColLastError] as String?,
      status: r[kColOpStatus] as String? ?? kOpStatusPending,
    );
  }

  /// Mark operation as syncing; on failure set status to failed and last_error.
  Future<void> _markOpSyncing(int opId) async {
    await _db.db.update(
      kTablePendingOps,
      {kColOpStatus: kOpStatusSyncing},
      where: '$kColOpId = ?',
      whereArgs: [opId],
    );
  }

  Future<void> _markOpCompleted(int opId) async {
    await _db.db.delete(kTablePendingOps, where: '$kColOpId = ?', whereArgs: [opId]);
    await _broadcastPendingCount();
  }

  Future<void> _markOpFailed(int opId, String error) async {
    final rows = await _db.db.query(
      kTablePendingOps,
      columns: [kColRetryCount],
      where: '$kColOpId = ?',
      whereArgs: [opId],
    );
    final current = rows.isNotEmpty ? (rows.first[kColRetryCount] as int? ?? 0) : 0;
    await _db.db.update(
      kTablePendingOps,
      {kColOpStatus: kOpStatusFailed, kColLastError: error, kColRetryCount: current + 1},
      where: '$kColOpId = ?',
      whereArgs: [opId],
    );
    await _broadcastPendingCount();
  }

  Future<void> _broadcastPendingCount() async {
    try {
      final count = await _getPendingCount();
      if (_pendingCountController.hasListener) _pendingCountController.add(count);
    } catch (_) {}
  }

  Future<int> _getPendingCount() async {
    await _db.ready;
    final r = await _db.db.rawQuery(
      'SELECT COUNT(*) as c FROM $kTablePendingOps WHERE $kColOpStatus = ? OR $kColOpStatus = ?',
      [kOpStatusPending, kOpStatusFailed],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// Run sync when online: process pending operations, then optionally refresh cache.
  Future<void> syncWhenOnline() async {
    if (!_isOnline || _syncing) return;
    _syncing = true;
    _syncingController.add(true);
    try {
      final pending = await getPendingOperations();
      for (final op in pending) {
        await _markOpSyncing(op.id);
        try {
          if (op.type == kOpTypeSendMessage) {
            await _executeSendMessage(op.payload);
          } else if (op.type == kOpTypeUpdateMessageStatus) {
            await _executeUpdateMessageStatus(op.payload);
          }
          await _markOpCompleted(op.id);
        } catch (e) {
          final err = e.toString();
          await _markOpFailed(op.id, err);
        }
      }
    } finally {
      _syncing = false;
      _syncingController.add(false);
    }
  }

  Future<void> _executeSendMessage(Map<String, dynamic> payload) async {
    final ref = _firestore.collection('messages').doc();
    final data = <String, dynamic>{
      'conversationId': payload['conversationId'] as String? ?? '',
      'senderId': payload['senderId'] as String? ?? _currentUserId,
      'senderType': payload['senderType'] as String? ?? 'admin',
      'encryptedContent': payload['encryptedContent'] as String? ?? '',
      'preview': payload['preview'] as String?,
      'timestamp': FieldValue.serverTimestamp(),
      'status': payload['status'] as String? ?? 'unread',
    };
    final iv = payload['iv'];
    if (iv != null && iv is List) data['iv'] = iv.cast<int>();
    await ref.set(data);
  }

  Future<void> _executeUpdateMessageStatus(Map<String, dynamic> payload) async {
    final messageId = payload['messageId'] as String?;
    final status = payload['status'] as String?;
    if (messageId == null || status == null) return;
    await _firestore.collection('messages').doc(messageId).update({'status': status});
  }

  /// Retry a single failed operation by id.
  Future<void> retryOperation(int opId) async {
    if (!_isOnline) return;
    final rows = await _db.db.query(kTablePendingOps, where: '$kColOpId = ?', whereArgs: [opId]);
    if (rows.isEmpty) return;
    final op = _rowToPendingOp(rows.first);
    await _markOpSyncing(op.id);
    try {
      if (op.type == kOpTypeSendMessage) {
        await _executeSendMessage(op.payload);
      } else if (op.type == kOpTypeUpdateMessageStatus) {
        await _executeUpdateMessageStatus(op.payload);
      }
      await _markOpCompleted(op.id);
    } catch (e) {
      await _markOpFailed(op.id, e.toString());
      rethrow;
    }
  }

  /// Retry all failed operations.
  Future<void> retryAllFailed() async {
    await syncWhenOnline();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _onlineController.close();
    _syncingController.close();
    _pendingCountController.close();
  }
}

void unawaited(Future<void> f) {}
