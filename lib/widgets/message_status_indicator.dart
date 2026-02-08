import 'package:flutter/material.dart';

import '../models/offline_message_state.dart';

/// Small indicator for message state: cached (offline), syncing, or synced.
class MessageStatusIndicator extends StatelessWidget {
  const MessageStatusIndicator({
    super.key,
    required this.state,
    this.size = 14,
    this.showLabel = false,
  });

  final OfflineMessageState state;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color color) = _style(theme);

    if (showLabel) {
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: size, color: color),
            const SizedBox(width: 4),
            Text(
              state.label,
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

  (IconData, Color) _style(ThemeData theme) {
    switch (state) {
      case OfflineMessageState.cached:
        return (Icons.offline_pin, theme.colorScheme.outline);
      case OfflineMessageState.syncing:
        return (Icons.sync, theme.colorScheme.primary);
      case OfflineMessageState.synced:
        return (Icons.cloud_done, theme.colorScheme.primary);
    }
  }
}
