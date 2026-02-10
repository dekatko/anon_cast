import 'package:flutter/material.dart';

import '../models/comparative_statistics.dart';

/// Small trend indicator: arrow + percentage. Green = positive, red = negative, grey = stable.
/// [changePercent] e.g. 23 or -15.
/// [trend] direction (up/down/stable).
/// [positiveIsGood] true for metrics where increase is good (e.g. messages); false for "lower is better" (e.g. response time).
class TrendIndicator extends StatelessWidget {
  const TrendIndicator({
    super.key,
    required this.changePercent,
    required this.trend,
    this.positiveIsGood = true,
    this.comparedToLabel,
  });

  final double changePercent;
  final TrendDirection trend;
  final bool positiveIsGood;
  final String? comparedToLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color;
    final IconData icon;
    switch (trend) {
      case TrendDirection.up:
        color = positiveIsGood ? Colors.green.shade700 : theme.colorScheme.error;
        icon = Icons.arrow_upward;
        break;
      case TrendDirection.down:
        color = positiveIsGood ? theme.colorScheme.error : Colors.green.shade700;
        icon = Icons.arrow_downward;
        break;
      case TrendDirection.stable:
        color = theme.colorScheme.onSurfaceVariant;
        icon = Icons.remove;
        break;
    }
    final text = _formatPercent(changePercent);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (comparedToLabel != null && comparedToLabel!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              comparedToLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatPercent(double percent) {
    if (percent == 0) return '0 %';
    final sign = percent > 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(0)} %';
  }
}
