import 'package:flutter/material.dart';

/// Banner or chip showing offline state. Use with StreamBuilder on connectivity.
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({
    super.key,
    required this.isOffline,
    this.bannerStyle = true,
    this.message,
  });

  final bool isOffline;
  final bool bannerStyle;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final text = message ?? 'Offline – messages will send when back online';

    if (bannerStyle) {
      return Material(
        color: theme.colorScheme.errorContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.cloud_off, color: theme.colorScheme.onErrorContainer, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}
