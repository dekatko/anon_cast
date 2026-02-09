import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/admin_message.dart';
import '../../../models/sync_status.dart';

/// Formats [dateTime] for the current locale (German-friendly).
String formatMessageTime(DateTime dateTime, String localeLanguageCode) {
  final locale = localeLanguageCode == 'de' ? 'de_DE' : 'en_US';
  return DateFormat('HH:mm', locale).format(dateTime);
}

/// Chat bubble for a single message. Admin on right, anonymous on left.
/// Shows encryption badge, and for own messages: sending/sent/failed status with optional retry.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.timeFormatted,
    required this.readStatusLabel,
    required this.semanticsLabel,
    required this.isEncrypted,
    this.syncStatus,
    this.onRetry,
    this.statusSendingLabel,
    this.statusFailedLabel,
    this.statusSentLabel,
    this.retryLabel,
    this.encryptionTooltipLabel,
  });

  final AdminMessage message;
  final String timeFormatted;
  final String readStatusLabel;
  final String semanticsLabel;
  final bool isEncrypted;
  final SyncStatus? syncStatus;
  final VoidCallback? onRetry;
  final String? statusSendingLabel;
  final String? statusFailedLabel;
  final String? statusSentLabel;
  final String? retryLabel;
  final String? encryptionTooltipLabel;

  String _sendingLabel(BuildContext context) =>
      statusSendingLabel ?? AppLocalizations.of(context).statusSending;
  String _failedLabel(BuildContext context) =>
      statusFailedLabel ?? AppLocalizations.of(context).statusFailed;
  String _sentLabel(BuildContext context) =>
      statusSentLabel ?? AppLocalizations.of(context).statusSent;
  String _retryLabel(BuildContext context) =>
      retryLabel ?? AppLocalizations.of(context).retry;
  String _encryptionTooltip(BuildContext context) =>
      encryptionTooltipLabel ?? AppLocalizations.of(context).encryptionTooltip;

  Widget _buildStatusIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final isFromAdmin = message.isFromAdmin;
    if (!isFromAdmin) return const SizedBox.shrink();
    final status = syncStatus;
    if (status == SyncStatus.sending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _sendingLabel(context),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      );
    }
    if (status == SyncStatus.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 14),
          const SizedBox(width: 4),
          Text(
            _failedLabel(context),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_retryLabel(context), style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
            ),
          ],
        ],
      );
    }
    if (status == SyncStatus.sent || status == SyncStatus.delivered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, color: Colors.green.shade700, size: 14),
          const SizedBox(width: 2),
          Text(
            _sentLabel(context),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          message.status == MessageStatus.read ? Icons.done_all : Icons.done,
          size: 14,
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 2),
        Text(
          readStatusLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildEncryptionBadge(BuildContext context) {
    if (!isEncrypted) return const SizedBox.shrink();
    final isFromAdmin = message.isFromAdmin;
    final theme = Theme.of(context);
    final color = Colors.green.shade700;
    return Tooltip(
      message: _encryptionTooltip(context),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'E2E',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isFromAdmin
                    ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFromAdmin = message.isFromAdmin;

    return Semantics(
      label: semanticsLabel,
      child: Align(
        alignment: isFromAdmin ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: isFromAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFromAdmin
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isFromAdmin ? 18 : 4),
                      bottomRight: Radius.circular(isFromAdmin ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.preview ?? (message.encryptedContent.isNotEmpty ? '[Encrypted]' : '—'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isFromAdmin
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            timeFormatted,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: (isFromAdmin
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurface)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                          if (isFromAdmin) ...[
                            const SizedBox(width: 6),
                            _buildStatusIndicator(context),
                          ],
                        ],
                      ),
                      _buildEncryptionBadge(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
