import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Full offline banner: shows offline state, optional syncing state, and retry for failed syncs.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.onRetry,
    this.message,
  });

  final bool isOffline;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!isOffline && !isSyncing && failedCount == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (isOffline) {
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
                    message ?? 'You\'re offline. Messages will send when back online.',
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

    if (failedCount > 0) {
      return Material(
        color: theme.colorScheme.errorContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.sync_problem, color: theme.colorScheme.onErrorContainer, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$failedCount failed to send',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: Text(l10n.retry, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (isSyncing || pendingCount > 0) {
      return Material(
        color: theme.colorScheme.primaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isSyncing
                        ? 'Syncing…'
                        : '${pendingCount} pending',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
