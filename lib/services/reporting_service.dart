import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../models/message_statistics.dart';
import '../models/response_time_analytics.dart';
import 'report_cache_service.dart';

/// Firestore whereIn limit (max 10 values per query).
const int _whereInLimit = 10;

/// Lightweight message metadata for reporting (no content; zero-knowledge).
class _MessageMeta {
  _MessageMeta({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.timestamp,
    required this.status,
    this.senderType,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final DateTime timestamp;
  final String status;
  final String? senderType;

  bool get isFromAdmin => senderType == 'admin';
  bool get isFromAnonymous => senderType == 'anonymous' || (senderType != 'admin' && senderId.isNotEmpty);
}

/// Fetches Firestore metadata and computes message statistics and response-time analytics.
/// Works only with metadata (timestamps, IDs, status, senderType); never reads message content.
class ReportingService {
  ReportingService({
    FirebaseFirestore? firestore,
    Logger? logger,
    ReportCacheService? reportCache,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _log = logger ?? Logger(),
        _reportCache = reportCache ?? ReportCacheService(logger: logger);

  final FirebaseFirestore _firestore;
  final Logger _log;
  final ReportCacheService _reportCache;

  static const String _conversationsCollection = 'conversations';
  static const String _messagesCollection = 'messages';

  /// Message statistics for [organizationId] between [startDate] and [endDate].
  /// Returns [MessageStatistics.empty] on error or when no data.
  Future<MessageStatistics> getMessageStatistics({
    required String organizationId,
    DateTime? startDate,
    DateTime? endDate,
    bool bypassCache = false,
  }) async {
    final end = endDate ?? DateTime.now();
    final start = startDate ?? end.subtract(const Duration(days: 7));
    final cacheKey = '${organizationId}_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';

    if (!bypassCache) {
      final cached = _reportCache.getCachedStatistics(cacheKey);
      if (cached != null) {
        _log.d('ReportingService: getMessageStatistics cache hit (returned <1ms)');
        return cached;
      }
    }

    final stopwatch = Stopwatch()..start();
    try {
      final conversationIds = await _getConversationIdsForOrganization(organizationId);
      if (conversationIds.isEmpty) {
        stopwatch.stop();
        _log.d('ReportingService: getMessageStatistics took ${stopwatch.elapsedMilliseconds}ms (no conversations)');
        final empty = MessageStatistics.empty();
        _reportCache.cacheStatistics(cacheKey, empty);
        return empty;
      }

      final messages = await _getMessagesForConversationsInRange(
        conversationIds,
        start,
        end,
      );
      final queryMs = stopwatch.elapsedMilliseconds;
      if (queryMs > 2000) {
        _log.w('ReportingService: slow query getMessageStatistics took ${queryMs}ms for ${messages.length} messages');
      } else {
        _log.d('ReportingService: getMessageStatistics took ${queryMs}ms (${messages.length} messages)');
      }

      final totalMessageCount = messages.length;
      final messagesByStatus = <String, int>{'unread': 0, 'read': 0, 'resolved': 0};
      int unreadCount = 0;
      for (final m in messages) {
        messagesByStatus[m.status] = (messagesByStatus[m.status] ?? 0) + 1;
        if (m.status == 'unread') unreadCount++;
      }
      final conversationIdsWithMessages = messages.map((m) => m.conversationId).toSet();
      final activeConversationCount = conversationIdsWithMessages.length;
      final days = end.difference(start).inDays.clamp(1, 365 * 10);
      final averageMessagesPerDay = totalMessageCount / days;
      final dailyTrend = _calculateDailyTrend(messages, start, end);

      final result = MessageStatistics(
        totalMessageCount: totalMessageCount,
        activeConversationCount: activeConversationCount,
        unreadMessageCount: unreadCount,
        averageMessagesPerDay: averageMessagesPerDay,
        messagesByStatus: messagesByStatus,
        dailyTrend: dailyTrend,
        periodStart: start,
        periodEnd: end,
      );
      _reportCache.cacheStatistics(cacheKey, result);
      return result;
    } catch (e, st) {
      stopwatch.stop();
      _log.e('ReportingService: getMessageStatistics failed after ${stopwatch.elapsedMilliseconds}ms', error: e, stackTrace: st);
      return MessageStatistics.empty();
    }
  }

  /// Response time analytics for [organizationId] between [startDate] and [endDate].
  /// Returns [ResponseTimeAnalytics.empty] on error or when no data.
  Future<ResponseTimeAnalytics> getResponseTimeAnalytics({
    required String organizationId,
    DateTime? startDate,
    DateTime? endDate,
    bool bypassCache = false,
  }) async {
    final end = endDate ?? DateTime.now();
    final start = startDate ?? end.subtract(const Duration(days: 7));
    final cacheKey = '${organizationId}_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';

    if (!bypassCache) {
      final cached = _reportCache.getCachedResponseTime(cacheKey);
      if (cached != null) {
        _log.d('ReportingService: getResponseTimeAnalytics cache hit (returned <1ms)');
        return cached;
      }
    }

    final stopwatch = Stopwatch()..start();
    try {
      final conversationIds = await _getConversationIdsForOrganization(organizationId);
      if (conversationIds.isEmpty) {
        stopwatch.stop();
        _log.d('ReportingService: getResponseTimeAnalytics took ${stopwatch.elapsedMilliseconds}ms (no convos)');
        final empty = ResponseTimeAnalytics.empty();
        _reportCache.cacheResponseTime(cacheKey, empty);
        return empty;
      }

      final messages = await _getMessagesForConversationsInRange(conversationIds, start, end);
      final queryMs = stopwatch.elapsedMilliseconds;
      if (queryMs > 2000) {
        _log.w('ReportingService: slow query getResponseTimeAnalytics took ${queryMs}ms for ${messages.length} messages');
      } else {
        _log.d('ReportingService: getResponseTimeAnalytics took ${queryMs}ms (${messages.length} messages)');
      }

      final byConversation = <String, List<_MessageMeta>>{};
      for (final m in messages) {
        byConversation.putIfAbsent(m.conversationId, () => []).add(m);
      }
      for (final list in byConversation.values) {
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      final firstResponseDurations = <Duration>[];
      final allResponseDurations = <Duration>[];
      int totalAnonymousMessages = 0;
      final adminResponseTimes = <String, List<Duration>>{}; // adminId -> list of response times
      final adminConversations = <String, Set<String>>{}; // adminId -> conversationIds
      final adminMessageCount = <String, int>{};

      for (final entry in byConversation.entries) {
        final list = entry.value;
        bool firstResponseRecorded = false;
        _MessageMeta? lastAnonymous;
        for (final m in list) {
          if (m.isFromAnonymous) {
            totalAnonymousMessages++;
            lastAnonymous = m;
          } else if (m.isFromAdmin) {
            if (lastAnonymous != null) {
              final duration = m.timestamp.difference(lastAnonymous.timestamp);
              if (duration.isNegative) continue;
              allResponseDurations.add(duration);
              if (!firstResponseRecorded) {
                firstResponseDurations.add(duration);
                firstResponseRecorded = true;
              }
              final aid = m.senderId;
              adminResponseTimes.putIfAbsent(aid, () => []).add(duration);
              adminConversations.putIfAbsent(aid, () => {}).add(entry.key);
              adminMessageCount[aid] = (adminMessageCount[aid] ?? 0) + 1;
            }
            lastAnonymous = null;
          }
        }
      }

      // Response rate: % of anonymous messages that received at least one reply (subsequent admin message in same conversation).
      int anonymousWithReply = 0;
      for (final list in byConversation.values) {
        for (int i = 0; i < list.length; i++) {
          if (!list[i].isFromAnonymous) continue;
          bool gotReply = false;
          for (int j = i + 1; j < list.length; j++) {
            if (list[j].isFromAdmin) {
              gotReply = true;
              break;
            }
          }
          if (gotReply) anonymousWithReply++;
        }
      }

      final totalResponsesCount = allResponseDurations.length;
      final responseRatePercent = totalAnonymousMessages > 0
          ? (anonymousWithReply / totalAnonymousMessages * 100)
          : 0.0;
      final avgFirst = firstResponseDurations.isEmpty
          ? Duration.zero
          : Duration(
              milliseconds: (firstResponseDurations.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / firstResponseDurations.length).round(),
            );
      final avgOverall = allResponseDurations.isEmpty
          ? Duration.zero
          : Duration(
              milliseconds: (allResponseDurations.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / allResponseDurations.length).round(),
            );

      final adminPerformanceList = <AdminPerformance>[];
      for (final aid in adminResponseTimes.keys) {
        final times = adminResponseTimes[aid]!;
        final avg = times.isEmpty
            ? Duration.zero
            : Duration(milliseconds: (times.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / times.length).round());
        adminPerformanceList.add(AdminPerformance(
          adminId: aid,
          adminName: aid, // Caller can resolve display name from users collection if needed
          conversationsHandled: adminConversations[aid]?.length ?? 0,
          messagesSent: adminMessageCount[aid] ?? 0,
          averageResponseTime: avg,
        ));
      }

      final result = ResponseTimeAnalytics(
        averageFirstResponseTime: avgFirst,
        averageResponseTimeOverall: avgOverall,
        responseRatePercent: responseRatePercent,
        totalResponsesCount: totalResponsesCount,
        adminPerformanceList: adminPerformanceList,
      );
      _reportCache.cacheResponseTime(cacheKey, result);
      return result;
    } catch (e, st) {
      stopwatch.stop();
      _log.e('ReportingService: getResponseTimeAnalytics failed after ${stopwatch.elapsedMilliseconds}ms', error: e, stackTrace: st);
      return ResponseTimeAnalytics.empty();
    }
  }

  /// Builds daily message counts for [messages] in [start]..[end] (inclusive).
  List<DailyMessageCount> _calculateDailyTrend(List<_MessageMeta> messages, DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final dayCounts = <DateTime, int>{};
    for (var d = startDate; !d.isAfter(endDate); d = d.add(const Duration(days: 1))) {
      dayCounts[d] = 0;
    }
    for (final m in messages) {
      final day = DateTime(m.timestamp.year, m.timestamp.month, m.timestamp.day);
      if (dayCounts.containsKey(day)) {
        dayCounts[day] = dayCounts[day]! + 1;
      }
    }
    final list = dayCounts.entries
        .map((e) => DailyMessageCount(date: e.key, count: e.value))
        .toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<List<String>> _getConversationIdsForOrganization(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection(_conversationsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      return snapshot.docs.map((d) => d.id).toList();
    } catch (e, st) {
      _log.e('ReportingService: _getConversationIdsForOrganization failed', error: e, stackTrace: st);
      return [];
    }
  }

  Future<List<_MessageMeta>> _getMessagesForConversationsInRange(
    List<String> conversationIds,
    DateTime start,
    DateTime end,
  ) async {
    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(end);
    final all = <_MessageMeta>[];
    for (var i = 0; i < conversationIds.length; i += _whereInLimit) {
      final batch = conversationIds.skip(i).take(_whereInLimit).toList();
      if (batch.isEmpty) continue;
      try {
        final snapshot = await _firestore
            .collection(_messagesCollection)
            .where('conversationId', whereIn: batch)
            .where('timestamp', isGreaterThanOrEqualTo: startTs)
            .where('timestamp', isLessThanOrEqualTo: endTs)
            .get();
        for (final doc in snapshot.docs) {
          final meta = _messageMetaFromDoc(doc.id, doc.data());
          if (meta != null) all.add(meta);
        }
      } catch (e) {
        _log.w('ReportingService: batch query failed for ${batch.length} ids', error: e);
        for (final cid in batch) {
          try {
            final snapshot = await _firestore
                .collection(_messagesCollection)
                .where('conversationId', isEqualTo: cid)
                .where('timestamp', isGreaterThanOrEqualTo: startTs)
                .where('timestamp', isLessThanOrEqualTo: endTs)
                .get();
            for (final doc in snapshot.docs) {
              final meta = _messageMetaFromDoc(doc.id, doc.data());
              if (meta != null) all.add(meta);
            }
          } catch (_) {}
        }
      }
    }
    return all;
  }

  _MessageMeta? _messageMetaFromDoc(String id, Map<String, dynamic> data) {
    try {
      final conversationId = data['conversationId'] as String? ?? '';
      if (conversationId.isEmpty) return null;
      final senderId = data['senderId'] as String? ?? '';
      final timestamp = _parseTimestamp(data['timestamp']);
      final status = (data['status'] as String?) ?? 'unread';
      final senderType = data['senderType'] as String?;
      return _MessageMeta(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        timestamp: timestamp,
        status: status,
        senderType: senderType,
      );
    } catch (_) {
      return null;
    }
  }

  DateTime _parseTimestamp(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  /// Clears in-memory caches (e.g. after org switch or for testing).
  void clearCache() {
    _reportCache.clearCache();
  }
}
