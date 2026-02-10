import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/comparative_statistics.dart';
import '../models/message_statistics.dart';
import 'trend_indicator.dart';

/// Single statistic card with icon, value, optional trend.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trendWidget,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Widget? trendWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (trendWidget != null) trendWidget!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Four statistics cards: total messages, active conversations, unread, average per day.
/// Optionally shows trend vs. previous period when [comparative] and [comparisonLabel] are set.
class StatisticsCards extends StatelessWidget {
  const StatisticsCards({
    super.key,
    required this.statistics,
    this.comparative,
    this.comparisonLabel,
  });

  final MessageStatistics statistics;
  final ComparativeStatistics? comparative;
  final String? comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final blue = theme.colorScheme.primary;
    final green = theme.colorScheme.tertiary;
    final orange = Colors.orange.shade700;
    final purple = Colors.deepPurple.shade600;

    final hasComparison = comparative != null && comparative!.hasPreviousPeriod;
    final label = comparisonLabel;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          title: l10n.totalMessages,
          value: '${statistics.totalMessageCount}',
          icon: Icons.message,
          color: blue,
          trendWidget: hasComparison
              ? TrendIndicator(
                  changePercent: comparative!.messageCountChangePercent,
                  trend: comparative!.messageCountTrend,
                  positiveIsGood: true,
                  comparedToLabel: label,
                )
              : null,
        ),
        _StatCard(
          title: l10n.activeConversations,
          value: '${statistics.activeConversationCount}',
          icon: Icons.chat_bubble_outline,
          color: green,
          trendWidget: hasComparison
              ? TrendIndicator(
                  changePercent: comparative!.activeConversationChangePercent,
                  trend: comparative!.activeConversationTrend,
                  positiveIsGood: true,
                  comparedToLabel: label,
                )
              : null,
        ),
        _StatCard(
          title: l10n.unreadMessages,
          value: '${statistics.unreadMessageCount}',
          icon: Icons.mark_email_unread,
          color: orange,
          trendWidget: hasComparison
              ? TrendIndicator(
                  changePercent: comparative!.unreadChangePercent,
                  trend: comparative!.unreadTrend,
                  positiveIsGood: false,
                  comparedToLabel: label,
                )
              : null,
        ),
        _StatCard(
          title: l10n.averagePerDay,
          value: statistics.averageMessagesPerDay.toStringAsFixed(1),
          icon: Icons.trending_up,
          color: purple,
          trendWidget: hasComparison
              ? TrendIndicator(
                  changePercent: comparative!.averagePerDayChangePercent,
                  trend: comparative!.averagePerDayTrend,
                  positiveIsGood: true,
                  comparedToLabel: label,
                )
              : null,
        ),
      ],
    );
  }
}
