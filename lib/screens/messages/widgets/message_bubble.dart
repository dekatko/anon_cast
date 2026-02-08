import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/admin_message.dart';

/// Formats [dateTime] for the current locale (German-friendly).
String formatMessageTime(DateTime dateTime, String localeLanguageCode) {
  final locale = localeLanguageCode == 'de' ? 'de_DE' : 'en_US';
  return DateFormat('HH:mm', locale).format(dateTime);
}

/// Chat bubble for a single message. Admin on right, anonymous on left.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.timeFormatted,
    required this.readStatusLabel,
    required this.semanticsLabel,
    required this.isEncrypted,
  });

  final AdminMessage message;
  final String timeFormatted;
  final String readStatusLabel;
  final String semanticsLabel;
  final bool isEncrypted;

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
                                  .withOpacity(0.7),
                            ),
                          ),
                          if (isFromAdmin) ...[
                            const SizedBox(width: 6),
                            Icon(
                              message.status == MessageStatus.read
                                  ? Icons.done_all
                                  : Icons.done,
                              size: 14,
                              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              readStatusLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isEncrypted)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                size: 12,
                                color: (isFromAdmin
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurface)
                                    .withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'E2E',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: (isFromAdmin
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface)
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
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
