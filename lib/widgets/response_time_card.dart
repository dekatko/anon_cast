import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/response_time_analytics.dart';

/// Color threshold for first response time: green <= 1h, yellow <= 4h, red > 4h.
Color _colorForFirstResponse(Duration d) {
  if (d.inMinutes <= 60) return Colors.green.shade700;
  if (d.inMinutes <= 240) return Colors.amber.shade700;
  return Colors.red.shade700;
}

/// Color for response rate: green >= 80%, yellow >= 50%, red < 50%.
Color _colorForResponseRate(double percent) {
  if (percent >= 80) return Colors.green.shade700;
  if (percent >= 50) return Colors.amber.shade700;
  return Colors.red.shade700;
}

/// Card showing average first response time, overall response time, and response rate.
class ResponseTimeCard extends StatelessWidget {
  const ResponseTimeCard({
    super.key,
    required this.analytics,
  });

  final ResponseTimeAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final firstResponseColor = _colorForFirstResponse(analytics.averageFirstResponseTime);
    final overallColor = _colorForFirstResponse(analytics.averageResponseTimeOverall);
    final rateColor = _colorForResponseRate(analytics.responseRatePercent);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  l10n.responseTimes,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Row(
              label: l10n.averageFirstResponse,
              value: analytics.averageFirstResponseTimeFormatted,
              color: firstResponseColor,
            ),
            const SizedBox(height: 8),
            _Row(
              label: l10n.averageResponseTime,
              value: analytics.averageResponseTimeOverallFormatted,
              color: overallColor,
            ),
            const SizedBox(height: 8),
            _Row(
              label: l10n.responseRate,
              value: '${analytics.responseRatePercent.toStringAsFixed(0)} %',
              color: rateColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
