import '../models/message_statistics.dart';
import '../models/response_time_analytics.dart';

/// Direction of change for trend display.
enum TrendDirection {
  up,
  down,
  stable,
}

/// Comparative analytics: current period vs previous period (same duration).
class ComparativeStatistics {
  const ComparativeStatistics({
    required this.currentStats,
    required this.previousStats,
    required this.currentResponseTime,
    required this.previousResponseTime,
  });

  final MessageStatistics currentStats;
  final MessageStatistics previousStats;
  final ResponseTimeAnalytics currentResponseTime;
  final ResponseTimeAnalytics previousResponseTime;

  /// Message count change (current - previous).
  int get messageCountChange =>
      currentStats.totalMessageCount - previousStats.totalMessageCount;

  /// Message count change as percentage of previous (0 if previous is 0).
  double get messageCountChangePercent =>
      previousStats.totalMessageCount == 0
          ? 0.0
          : (messageCountChange / previousStats.totalMessageCount) * 100;

  /// Active conversation count change.
  int get activeConversationChange =>
      currentStats.activeConversationCount - previousStats.activeConversationCount;

  double get activeConversationChangePercent =>
      previousStats.activeConversationCount == 0
          ? 0.0
          : (activeConversationChange / previousStats.activeConversationCount) * 100;

  /// Unread count change.
  int get unreadChange =>
      currentStats.unreadMessageCount - previousStats.unreadMessageCount;

  double get unreadChangePercent =>
      previousStats.unreadMessageCount == 0
          ? 0.0
          : (unreadChange / previousStats.unreadMessageCount) * 100;

  /// Average messages per day change.
  double get averagePerDayChange =>
      currentStats.averageMessagesPerDay - previousStats.averageMessagesPerDay;

  double get averagePerDayChangePercent =>
      previousStats.averageMessagesPerDay == 0
          ? 0.0
          : (averagePerDayChange / previousStats.averageMessagesPerDay) * 100;

  /// First response time change in milliseconds (negative = faster).
  int get firstResponseTimeChangeMs =>
      currentResponseTime.averageFirstResponseTime.inMilliseconds -
      previousResponseTime.averageFirstResponseTime.inMilliseconds;

  /// Overall response time change in ms (negative = faster).
  int get overallResponseTimeChangeMs =>
      currentResponseTime.averageResponseTimeOverall.inMilliseconds -
      previousResponseTime.averageResponseTimeOverall.inMilliseconds;

  /// Response rate change in percentage points.
  double get responseRateChangePercent =>
      currentResponseTime.responseRatePercent - previousResponseTime.responseRatePercent;

  /// Trend for message count: up = more messages, down = fewer, stable if |%| < 5.
  TrendDirection get messageCountTrend => _trendFromPercent(messageCountChangePercent);

  TrendDirection get activeConversationTrend => _trendFromPercent(activeConversationChangePercent);

  TrendDirection get unreadTrend => _trendFromPercent(unreadChangePercent);

  TrendDirection get averagePerDayTrend => _trendFromPercent(averagePerDayChangePercent);

  /// For response time: down = faster = good, up = slower = bad, stable if small change.
  TrendDirection get firstResponseTimeTrend {
    if (firstResponseTimeChangeMs.abs() < 60 * 1000) return TrendDirection.stable; // < 1 min
    return firstResponseTimeChangeMs < 0 ? TrendDirection.down : TrendDirection.up;
  }

  TrendDirection get overallResponseTimeTrend {
    if (overallResponseTimeChangeMs.abs() < 60 * 1000) return TrendDirection.stable;
    return overallResponseTimeChangeMs < 0 ? TrendDirection.down : TrendDirection.up;
  }

  TrendDirection get responseRateTrend => _trendFromPercent(responseRateChangePercent);

  static TrendDirection _trendFromPercent(double percent) {
    if (percent.abs() < 5) return TrendDirection.stable;
    return percent > 0 ? TrendDirection.up : TrendDirection.down;
  }

  /// German-formatted change string for message count, e.g. "+23 %" or "-12 %".
  String get messageCountChangeFormatted => _formatPercent(messageCountChangePercent);

  String get activeConversationChangeFormatted => _formatPercent(activeConversationChangePercent);

  String get unreadChangeFormatted => _formatPercent(unreadChangePercent);

  String get averagePerDayChangeFormatted => _formatPercent(averagePerDayChangePercent);

  String get responseRateChangeFormatted => _formatPercent(responseRateChangePercent);

  static String _formatPercent(double percent) {
    if (percent == 0) return '0 %';
    final sign = percent > 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(0)} %';
  }

  /// Whether we have valid previous-period data (so comparison is meaningful).
  bool get hasPreviousPeriod =>
      !previousStats.isEmpty || !previousResponseTime.isEmpty;
}
