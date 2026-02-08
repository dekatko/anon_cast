import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Keys for Hive boxes.
const String kMessageCacheBox = 'message_sync_cache';
const String kPendingMessagesBox = 'message_sync_pending';

/// Cache entry: list of message maps (JSON-serializable) for a conversation.
/// We store Map<String, dynamic> per message; key = conversationId, value = list of maps.
const String kCacheKeyPrefix = 'conv_';
const int kMaxCachedMessagesPerConversation = 500;
const int kMaxCacheAgeDays = 7;

/// Pending message: key = localId (uuid), value = map with conversationId, senderId, etc. + retryCount, createdAt, nextRetryAt.
const int kMaxPendingAgeDays = 3;

/// Local cache and pending queue for messages (Hive). No adapters needed; we store JSON maps.
class MessageCache {
  MessageCache._();
  static final MessageCache _instance = MessageCache._();
  static MessageCache get instance => _instance;

  Box<String>? _cacheBox;
  Box<String>? _pendingBox;

  Future<void> init() async {
    _cacheBox ??= await Hive.openBox<String>(kMessageCacheBox);
    _pendingBox ??= await Hive.openBox<String>(kPendingMessagesBox);
  }

  Box<String> get _cache {
    final b = _cacheBox;
    if (b == null) throw StateError('MessageCache not initialized. Call init() first.');
    return b;
  }

  Box<String> get _pending {
    final b = _pendingBox;
    if (b == null) throw StateError('MessageCache not initialized. Call init() first.');
    return b;
  }

  // ---------- Cache (server messages for offline read) ----------

  String _cacheKey(String conversationId) => '$kCacheKeyPrefix$conversationId';

  /// Replace cached messages for a conversation (e.g. after Firestore snapshot).
  Future<void> setCachedMessages(String conversationId, List<Map<String, dynamic>> messages) async {
    final list = messages.map((m) => _toJsonSafe(m)).toList();
    if (list.length > kMaxCachedMessagesPerConversation) {
      list.removeRange(0, list.length - kMaxCachedMessagesPerConversation);
    }
    await _cache.put(_cacheKey(conversationId), jsonEncode(list));
  }

  /// Get cached messages for a conversation. Returns empty list if none.
  List<Map<String, dynamic>> getCachedMessages(String conversationId) {
    final raw = _cache.get(_cacheKey(conversationId));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove cache for a conversation.
  Future<void> clearConversationCache(String conversationId) async {
    await _cache.delete(_cacheKey(conversationId));
  }

  /// Remove cache entries older than [kMaxCacheAgeDays] (by conversation key; we don't store per-message time).
  /// Call periodically; for simplicity we only clear if box is large.
  Future<void> clearOldCache() async {
    final keys = _cache.keys.where((k) => k is String && (k as String).startsWith(kCacheKeyPrefix)).toList();
    if (keys.length <= 20) return;
    final toDelete = keys.length - 10;
    for (var i = 0; i < toDelete && i < keys.length; i++) {
      await _cache.delete(keys[i]);
    }
  }

  // ---------- Pending queue (unsent messages) ----------

  /// Add a pending message. [payload] must include conversationId, senderId, encryptedContent, timestamp, status, etc.
  Future<void> addPending(String localId, Map<String, dynamic> payload, {int retryCount = 0}) async {
    final map = <String, dynamic>{...payload};
    map['retryCount'] = retryCount;
    map['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    map['nextRetryAt'] = DateTime.now().millisecondsSinceEpoch;
    map['syncStatus'] = 'sending';
    await _pending.put(localId, jsonEncode(map));
  }

  static Map<dynamic, dynamic>? _decodePending(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<dynamic, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<String> getPendingLocalIds(String conversationId) {
    final ids = <String>[];
    for (final key in _pending.keys) {
      if (key is! String) continue;
      final m = _decodePending(_pending.get(key));
      if (m != null && m['conversationId'] == conversationId) ids.add(key);
    }
    return ids;
  }

  Map<dynamic, dynamic>? getPending(String localId) => _decodePending(_pending.get(localId));

  List<Map<dynamic, dynamic>> getAllPending() {
    return _pending.values.map(_decodePending).whereType<Map<dynamic, dynamic>>().toList();
  }

  /// All local IDs in the pending queue (for sync on reconnect).
  List<String> getAllPendingIds() {
    return _pending.keys.whereType<String>().toList();
  }

  /// Mark pending as sent and remove from queue.
  Future<void> removePending(String localId) async {
    await _pending.delete(localId);
  }

  /// Update retry state (nextRetryAt, retryCount, syncStatus).
  Future<void> updatePending(String localId, Map<dynamic, dynamic> updates) async {
    final raw = _pending.get(localId);
    if (raw == null) return;
    final m = _decodePending(raw);
    if (m == null) return;
    final map = Map<String, dynamic>.from(m);
    for (final e in updates.entries) {
      map[e.key.toString()] = e.value;
    }
    await _pending.put(localId, jsonEncode(map));
  }

  /// Remove pending older than [kMaxPendingAgeDays].
  Future<void> clearOldPending() async {
    final cutoff = DateTime.now().subtract(Duration(days: kMaxPendingAgeDays)).millisecondsSinceEpoch;
    for (final key in _pending.keys.toList()) {
      final raw = _pending.get(key);
      final m = _decodePending(raw);
      if (m != null && ((m['createdAt'] as num?)?.toInt() ?? 0) < cutoff) {
        await _pending.delete(key);
      }
    }
  }

  static Map<String, dynamic> _toJsonSafe(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    for (final e in m.entries) {
      final v = e.value;
      if (v is DateTime) {
        out[e.key] = v.millisecondsSinceEpoch;
      } else if (v != null && v.runtimeType.toString().contains('Timestamp')) {
        out[e.key] = (v as dynamic).millisecondsSinceEpoch ?? v.milliseconds;
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }
}
