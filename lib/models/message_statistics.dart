import 'package:intl/intl.dart';

/// Single day's message count for trend charts (e.g. admin dashboard).
class DailyMessageCount {
  const DailyMessageCount({
    required this.date,
    required this.count,
  });

  final DateTime date;
  final int count;

  /// Date formatted for German locale (dd.MM).
  String get formattedDate {
    return DateFormat('dd.MM', 'de').format(date);
  }

  /// Date formatted with year for longer ranges (dd.MM.yyyy).
  String get formattedDateWithYear {
    return DateFormat('dd.MM.yyyy', 'de').format(date);
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'count': count,
      };

  factory DailyMessageCount.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'];
    DateTime date = DateTime.now();
    if (dateRaw is String) date = DateTime.tryParse(dateRaw) ?? date;
    if (dateRaw is int) date = DateTime.fromMillisecondsSinceEpoch(dateRaw);
    final count = (json['count'] is int) ? json['count'] as int : (json['count'] as num?)?.toInt() ?? 0;
    return DailyMessageCount(date: date, count: count);
  }
}

/// Aggregated message and conversation statistics for a time period (admin reporting).
class MessageStatistics {
  const MessageStatistics({
    required this.totalMessageCount,
    required this.activeConversationCount,
    required this.unreadMessageCount,
    required this.averageMessagesPerDay,
    required this.messagesByStatus,
    required this.dailyTrend,
    this.periodStart,
    this.periodEnd,
  });

  final int totalMessageCount;
  final int activeConversationCount;
  final int unreadMessageCount;
  final double averageMessagesPerDay;
  /// Message counts by status: keys 'unread', 'read', 'resolved'.
  final Map<String, int> messagesByStatus;
  final List<DailyMessageCount> dailyTrend;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// Empty / error state: all counts zero, empty lists.
  factory MessageStatistics.empty() {
    return MessageStatistics(
      totalMessageCount: 0,
      activeConversationCount: 0,
      unreadMessageCount: 0,
      averageMessagesPerDay: 0,
      messagesByStatus: const {},
      dailyTrend: const [],
      periodStart: null,
      periodEnd: null,
    );
  }

  /// Whether this instance represents an empty/error state.
  bool get isEmpty =>
      totalMessageCount == 0 &&
      activeConversationCount == 0 &&
      unreadMessageCount == 0 &&
      dailyTrend.isEmpty;

  Map<String, dynamic> toJson() => {
        'totalMessageCount': totalMessageCount,
        'activeConversationCount': activeConversationCount,
        'unreadMessageCount': unreadMessageCount,
        'averageMessagesPerDay': averageMessagesPerDay,
        'messagesByStatus': Map<String, int>.from(messagesByStatus),
        'dailyTrend': dailyTrend.map((e) => e.toJson()).toList(),
        'periodStart': periodStart?.toIso8601String(),
        'periodEnd': periodEnd?.toIso8601String(),
      };

  factory MessageStatistics.fromJson(Map<String, dynamic> json) {
    final byStatus = json['messagesByStatus'];
    final Map<String, int> messagesByStatus = {};
    if (byStatus is Map) {
      for (final e in (byStatus as Map).entries) {
        final k = e.key?.toString();
        final v = e.value;
        if (k != null) messagesByStatus[k] = v is int ? v : (v as num?)?.toInt() ?? 0;
      }
    }
    final list = json['dailyTrend'];
    final List<DailyMessageCount> dailyTrend = [];
    if (list is List) {
      for (final e in list) {
        if (e is Map<String, dynamic>) dailyTrend.add(DailyMessageCount.fromJson(e));
      }
    }
    DateTime? periodStart;
    DateTime? periodEnd;
    final ps = json['periodStart'];
    if (ps is String) periodStart = DateTime.tryParse(ps);
    if (ps is int) periodStart = DateTime.fromMillisecondsSinceEpoch(ps);
    final pe = json['periodEnd'];
    if (pe is String) periodEnd = DateTime.tryParse(pe);
    if (pe is int) periodEnd = DateTime.fromMillisecondsSinceEpoch(pe);
    return MessageStatistics(
      totalMessageCount: (json['totalMessageCount'] as num?)?.toInt() ?? 0,
      activeConversationCount: (json['activeConversationCount'] as num?)?.toInt() ?? 0,
      unreadMessageCount: (json['unreadMessageCount'] as num?)?.toInt() ?? 0,
      averageMessagesPerDay: (json['averageMessagesPerDay'] as num?)?.toDouble() ?? 0,
      messagesByStatus: messagesByStatus,
      dailyTrend: dailyTrend,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }
}
