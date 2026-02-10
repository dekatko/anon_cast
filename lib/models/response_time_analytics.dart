/// Performance data for a single admin (response time reporting).
class AdminPerformance {
  const AdminPerformance({
    required this.adminId,
    required this.adminName,
    required this.conversationsHandled,
    required this.messagesSent,
    required this.averageResponseTime,
  });

  final String adminId;
  final String adminName;
  final int conversationsHandled;
  final int messagesSent;
  /// Average time to respond in conversations.
  final Duration averageResponseTime;

  Map<String, dynamic> toJson() => {
        'adminId': adminId,
        'adminName': adminName,
        'conversationsHandled': conversationsHandled,
        'messagesSent': messagesSent,
        'averageResponseTimeMillis': averageResponseTime.inMilliseconds,
      };

  factory AdminPerformance.fromJson(Map<String, dynamic> json) {
    final ms = (json['averageResponseTimeMillis'] as num?)?.toInt();
    return AdminPerformance(
      adminId: json['adminId'] as String? ?? '',
      adminName: json['adminName'] as String? ?? '',
      conversationsHandled: (json['conversationsHandled'] as num?)?.toInt() ?? 0,
      messagesSent: (json['messagesSent'] as num?)?.toInt() ?? 0,
      averageResponseTime: ms != null ? Duration(milliseconds: ms) : Duration.zero,
    );
  }
}

/// Response time and admin performance analytics for the reporting period.
class ResponseTimeAnalytics {
  const ResponseTimeAnalytics({
    required this.averageFirstResponseTime,
    required this.averageResponseTimeOverall,
    required this.responseRatePercent,
    required this.totalResponsesCount,
    required this.adminPerformanceList,
  });

  /// Average time until first admin response in a conversation.
  final Duration averageFirstResponseTime;
  /// Average time between messages (overall response time).
  final Duration averageResponseTimeOverall;
  final double responseRatePercent;
  final int totalResponsesCount;
  final List<AdminPerformance> adminPerformanceList;

  /// Empty / error state.
  factory ResponseTimeAnalytics.empty() {
    return ResponseTimeAnalytics(
      averageFirstResponseTime: Duration.zero,
      averageResponseTimeOverall: Duration.zero,
      responseRatePercent: 0,
      totalResponsesCount: 0,
      adminPerformanceList: const [],
    );
  }

  bool get isEmpty =>
      totalResponsesCount == 0 && adminPerformanceList.isEmpty;

  /// Formats [duration] for German locale (e.g. "2 h 30 min", "45 min", "1 Tag 2 Std.").
  static String formatDurationGerman(Duration duration) {
    if (duration.inMilliseconds < 0) return '—';
    if (duration.inMinutes < 1) return '< 1 min';
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('$days ${days == 1 ? "Tag" : "Tage"}');
    if (hours > 0) parts.add('$hours ${hours == 1 ? "Std." : "Std."}');
    if (minutes > 0 || parts.isEmpty) parts.add('$minutes min');
    return parts.join(' ');
  }

  /// Short form for tooltips (e.g. "2 h 30 min").
  static String formatDurationGermanShort(Duration duration) {
    if (duration.inMilliseconds < 0) return '—';
    if (duration.inMinutes < 1) return '< 1 min';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours >= 24) {
      final days = duration.inDays;
      final h = hours % 24;
      if (h > 0) return '${days}d ${h}h ${minutes}min';
      return '${days}d ${minutes}min';
    }
    if (hours > 0) return '${hours}h ${minutes}min';
    return '${minutes}min';
  }

  /// Display string for average first response time (German).
  String get averageFirstResponseTimeFormatted =>
      formatDurationGerman(averageFirstResponseTime);

  /// Display string for average response time overall (German).
  String get averageResponseTimeOverallFormatted =>
      formatDurationGerman(averageResponseTimeOverall);

  Map<String, dynamic> toJson() => {
        'averageFirstResponseTimeMillis': averageFirstResponseTime.inMilliseconds,
        'averageResponseTimeOverallMillis': averageResponseTimeOverall.inMilliseconds,
        'responseRatePercent': responseRatePercent,
        'totalResponsesCount': totalResponsesCount,
        'adminPerformanceList': adminPerformanceList.map((e) => e.toJson()).toList(),
      };

  factory ResponseTimeAnalytics.fromJson(Map<String, dynamic> json) {
    final list = json['adminPerformanceList'];
    final List<AdminPerformance> adminPerformanceList = [];
    if (list is List) {
      for (final e in list) {
        if (e is Map<String, dynamic>) adminPerformanceList.add(AdminPerformance.fromJson(e));
      }
    }
    final firstMs = (json['averageFirstResponseTimeMillis'] as num?)?.toInt();
    final overallMs = (json['averageResponseTimeOverallMillis'] as num?)?.toInt();
    return ResponseTimeAnalytics(
      averageFirstResponseTime: firstMs != null ? Duration(milliseconds: firstMs) : Duration.zero,
      averageResponseTimeOverall: overallMs != null ? Duration(milliseconds: overallMs) : Duration.zero,
      responseRatePercent: (json['responseRatePercent'] as num?)?.toDouble() ?? 0,
      totalResponsesCount: (json['totalResponsesCount'] as num?)?.toInt() ?? 0,
      adminPerformanceList: adminPerformanceList,
    );
  }
}
