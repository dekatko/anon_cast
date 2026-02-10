import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/response_time_analytics.dart';

/// Card for one admin in the leaderboard: rank badge, name, key metrics.
class AdminPerformanceCard extends StatelessWidget {
  const AdminPerformanceCard({
    super.key,
    required this.performance,
    required this.periodDays,
    this.onTap,
  });

  final AdminPerformance performance;
  final int periodDays;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rank = performance.rank ?? 0;
    final rankWidget = _buildRankBadge(context, rank);
    final messagesPerDay = periodDays > 0
        ? (performance.messagesSent / periodDays).toStringAsFixed(1)
        : '—';
    final responseStr = ResponseTimeAnalytics.formatDurationGerman(performance.averageResponseTime);

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              rankWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      performance.adminName.isNotEmpty
                          ? performance.adminName
                          : performance.adminId,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _metricChip(
                          context,
                          l10n.conversationsHandled,
                          '${performance.conversationsHandled}',
                        ),
                        const SizedBox(width: 8),
                        _metricChip(
                          context,
                          l10n.messagesPerDay,
                          messagesPerDay,
                        ),
                        const SizedBox(width: 8),
                        _metricChip(
                          context,
                          l10n.averageResponseTime,
                          responseStr,
                          isTime: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(BuildContext context, int rank) {
    final theme = Theme.of(context);
    IconData? medal;
    Color? color;
    if (rank == 1) {
      medal = Icons.emoji_events;
      color = Colors.amber.shade700;
    } else if (rank == 2) {
      medal = Icons.emoji_events;
      color = Colors.grey.shade600;
    } else if (rank == 3) {
      medal = Icons.emoji_events;
      color = Colors.brown.shade700;
    }
    if (medal != null) {
      return Icon(medal, size: 32, color: color);
    }
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _metricChip(
    BuildContext context,
    String label,
    String value, {
    bool isTime = false,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: Text(
        isTime ? value : '$label: $value',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
