import 'response_time_analytics.dart';

/// Engagement and usage metrics for the admin dashboard (anonymous users, completion, peak hours).
class EngagementMetrics {
  const EngagementMetrics({
    required this.uniqueAnonymousUserCount,
    required this.conversationCompletionRatePercent,
    required this.peakUsageHours,
    required this.averageConversationDuration,
    required this.returnUserRatePercent,
  });

  final int uniqueAnonymousUserCount;
  /// Percentage (0–100) of conversations that reached a resolved/closed state.
  final double conversationCompletionRatePercent;
  /// Hour indices (0–23) with highest activity, e.g. [9, 10, 14].
  final List<int> peakUsageHours;
  final Duration averageConversationDuration;
  /// Percentage (0–100) of anonymous users who had more than one conversation.
  final double returnUserRatePercent;

  /// Empty / error state.
  factory EngagementMetrics.empty() {
    return EngagementMetrics(
      uniqueAnonymousUserCount: 0,
      conversationCompletionRatePercent: 0,
      peakUsageHours: const [],
      averageConversationDuration: Duration.zero,
      returnUserRatePercent: 0,
    );
  }

  bool get isEmpty =>
      uniqueAnonymousUserCount == 0 && peakUsageHours.isEmpty;

  /// Peak hours formatted for German display (e.g. "9–11, 14 Uhr").
  String get peakUsageHoursFormatted {
    if (peakUsageHours.isEmpty) return '—';
    final sorted = List<int>.from(peakUsageHours)..sort();
    final parts = <String>[];
    int? rangeStart;
    int? rangeEnd;
    for (final h in sorted) {
      if (rangeStart == null) {
        rangeStart = h;
        rangeEnd = h;
      } else if (h == rangeEnd! + 1) {
        rangeEnd = h;
      } else {
        parts.add(rangeStart == rangeEnd
            ? '${rangeStart} Uhr'
            : '${rangeStart}–${rangeEnd} Uhr');
        rangeStart = h;
        rangeEnd = h;
      }
    }
    if (rangeStart != null) {
      parts.add(rangeStart == rangeEnd
          ? '${rangeStart} Uhr'
          : '${rangeStart}–${rangeEnd} Uhr');
    }
    return parts.join(', ');
  }

  /// Average conversation duration formatted for German (e.g. "2 h 30 min").
  String get averageConversationDurationFormatted {
    return ResponseTimeAnalytics.formatDurationGerman(averageConversationDuration);
  }

  Map<String, dynamic> toJson() => {
        'uniqueAnonymousUserCount': uniqueAnonymousUserCount,
        'conversationCompletionRatePercent': conversationCompletionRatePercent,
        'peakUsageHours': List<int>.from(peakUsageHours),
        'averageConversationDurationMillis': averageConversationDuration.inMilliseconds,
        'returnUserRatePercent': returnUserRatePercent,
      };

  factory EngagementMetrics.fromJson(Map<String, dynamic> json) {
    final hours = json['peakUsageHours'];
    final List<int> peakUsageHours = [];
    if (hours is List) {
      for (final e in hours) {
        if (e is int) peakUsageHours.add(e);
        if (e is num) peakUsageHours.add(e.toInt());
      }
    }
    final ms = (json['averageConversationDurationMillis'] as num?)?.toInt();
    return EngagementMetrics(
      uniqueAnonymousUserCount: (json['uniqueAnonymousUserCount'] as num?)?.toInt() ?? 0,
      conversationCompletionRatePercent:
          (json['conversationCompletionRatePercent'] as num?)?.toDouble() ?? 0,
      peakUsageHours: peakUsageHours,
      averageConversationDuration:
          ms != null ? Duration(milliseconds: ms) : Duration.zero,
      returnUserRatePercent: (json['returnUserRatePercent'] as num?)?.toDouble() ?? 0,
    );
  }
}
