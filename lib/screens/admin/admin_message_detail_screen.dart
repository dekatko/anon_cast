import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin_message.dart';
import '../../provider/admin_messages_provider.dart';
import '../messages/message_thread_screen.dart';

/// Message detail and reply screen for a single anonymous message.
class AdminMessageDetailScreen extends StatelessWidget {
  const AdminMessageDetailScreen({super.key, required this.message});

  final AdminMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messageDetailTitle),
        actions: [
          if (message.isUnread)
            TextButton.icon(
              onPressed: () async {
                await context.read<AdminMessagesProvider>().markAsRead(message.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.done_all, size: 20),
              label: Text(l10n.markRead),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'read') {
                await context.read<AdminMessagesProvider>().markAsRead(message.id);
              } else if (value == 'resolved') {
                await context.read<AdminMessagesProvider>().markAsResolved(message.id);
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'read', child: Text(l10n.markRead)),
              PopupMenuItem(value: 'resolved', child: Text(l10n.markResolved)),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final padding = isWide ? 24.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: isWide ? BoxConstraints(maxWidth: 600) : BoxConstraints(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.anonymousSender,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(theme, message.status).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    message.status.value,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: _statusColor(theme, message.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat.yMMMd().add_Hm().format(message.timestamp),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text(
                              message.preview ?? (message.encryptedContent.isNotEmpty ? '[Encrypted content — decrypt in conversation]' : '—'),
                              style: theme.textTheme.bodyLarge,
                            ),
                            if (message.encryptedContent.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Encrypted payload (decrypt with conversation key in chat flow).',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        final cid = message.conversationId;
                        if (cid.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.noConversationId)),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => MessageThreadScreen(
                              conversationId: cid,
                              initialMessage: message,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.reply),
                      label: Text(l10n.reply),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(ThemeData theme, MessageStatus status) {
    switch (status) {
      case MessageStatus.unread:
        return theme.colorScheme.primary;
      case MessageStatus.read:
        return theme.colorScheme.tertiary;
      case MessageStatus.resolved:
        return theme.colorScheme.secondary;
    }
  }
}
