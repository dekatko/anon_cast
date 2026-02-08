import 'package:flutter/material.dart';

/// Button to retry failed syncs. Use with [onRetry] from [OfflineService.retryAllFailed] or [retryOperation].
class RetrySyncButton extends StatelessWidget {
  const RetrySyncButton({
    super.key,
    required this.onRetry,
    this.label = 'Retry',
    this.icon = Icons.sync,
  });

  final VoidCallback? onRetry;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onRetry,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
