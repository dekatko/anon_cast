import 'package:flutter/material.dart';

import '../models/sync_status.dart';

/// Small icon or chip indicating message sync state (sending, sent, failed).
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.status,
    this.size = 14,
    this.showLabel = false,
  });

  final SyncStatus status;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color color, String label) = _style(theme);

    if (showLabel) {
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: size, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(icon, size: size, color: color),
    );
  }

  (IconData, Color, String) _style(ThemeData theme) {
    switch (status) {
      case SyncStatus.sending:
        return (Icons.schedule, theme.colorScheme.primary, 'Sending…');
      case SyncStatus.sent:
        return (Icons.done, theme.colorScheme.primary, 'Sent');
      case SyncStatus.delivered:
        return (Icons.done_all, theme.colorScheme.primary, 'Delivered');
      case SyncStatus.failed:
        return (Icons.error_outline, theme.colorScheme.error, 'Failed');
    }
  }
}
