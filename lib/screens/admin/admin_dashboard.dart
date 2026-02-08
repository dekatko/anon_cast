import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin_message.dart';
import '../../provider/admin_messages_provider.dart';
import 'admin_message_detail_screen.dart';

/// Admin dashboard: real-time list of anonymous messages with filters,
/// unread badge, pull-to-refresh, and navigation to detail/reply.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminMessagesProvider>();
      provider.startListening(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AdminMessagesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDashboardTitle),
        centerTitle: true,
        actions: [
          _UnreadBadge(count: provider.unreadCount),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FiltersSection(
            searchController: _searchController,
            searchFocus: _searchFocus,
            onSearchChanged: provider.setSearchQuery,
          ),
          Expanded(
            child: _BodyContent(
              provider: provider,
              onTapMessage: (msg) => _openDetail(context, msg),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, AdminMessage message) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AdminMessageDetailScreen(message: message),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Center(
      child: Badge(
        label: Text('$count'),
        child: IconButton(
          icon: const Icon(Icons.mark_email_unread_outlined),
          onPressed: () {
            context.read<AdminMessagesProvider>().setStatusFilter(MessageStatus.unread);
          },
        ),
      ),
    );
  }
}

class _FiltersSection extends StatelessWidget {
  const _FiltersSection({
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String?> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AdminMessagesProvider>();
    final filter = provider.filter;

    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              focusNode: searchFocus,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${l10n.filterByStatus}: ', style: Theme.of(context).textTheme.labelLarge),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilterChip(
                          label: Text(l10n.filterAll),
                          selected: filter.status == null,
                          onSelected: (_) =>
                              provider.setStatusFilter(null),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(l10n.filterUnread),
                          selected: filter.status == MessageStatus.unread,
                          onSelected: (_) =>
                              provider.setStatusFilter(MessageStatus.unread),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(l10n.filterRead),
                          selected: filter.status == MessageStatus.read,
                          onSelected: (_) =>
                              provider.setStatusFilter(MessageStatus.read),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(l10n.filterResolved),
                          selected: filter.status == MessageStatus.resolved,
                          onSelected: (_) =>
                              provider.setStatusFilter(MessageStatus.resolved),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DateFilterChips(provider: provider),
          ],
        ),
      ),
    );
  }
}

class _DateFilterChips extends StatelessWidget {
  const _DateFilterChips({required this.provider});

  final AdminMessagesProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    return Row(
      children: [
        Text('${l10n.filterByDate}: ', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ActionChip(
              label: const Text('Today'),
              onPressed: () => provider.setDateRange(today, now),
            ),
            ActionChip(
              label: const Text('Yesterday'),
              onPressed: () => provider.setDateRange(yesterday, yesterday),
            ),
            ActionChip(
              label: const Text('This week'),
              onPressed: () => provider.setDateRange(weekStart, now),
            ),
            ActionChip(
              label: const Text('Clear'),
              onPressed: () => provider.setDateRange(null, null),
            ),
          ],
        ),
      ],
    );
  }
}

class _BodyContent extends StatelessWidget {
  const _BodyContent({
    required this.provider,
    required this.onTapMessage,
  });

  final AdminMessagesProvider provider;
  final ValueChanged<AdminMessage> onTapMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (provider.hasError) {
      return _ErrorState(
        message: l10n.errorLoading,
        retryLabel: l10n.retry,
        onRetry: () => provider.refresh(),
      );
    }

    if (provider.isLoading && provider.filteredMessages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = provider.filteredMessages;
    if (list.isEmpty) {
      return _EmptyState(
        title: l10n.emptyTitle,
        subtitle: l10n.emptySubtitle,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return RefreshIndicator(
          onRefresh: () => provider.refresh(),
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 16,
              vertical: 12,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final msg = list[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MessageCard(
                  message: msg,
                  onTap: () => onTapMessage(msg),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.onTap});

  final AdminMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasContent = message.encryptedContent.isNotEmpty;
    final preview = message.preview ?? (hasContent ? '[Encrypted]' : '—');
    final time = DateFormat.yMMMd().add_Hm().format(message.timestamp);
    final isUnread = message.isUnread;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUnread
            ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isUnread
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  isUnread ? Icons.mail : Icons.mail_outline,
                  color: message.isUnread
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.anonymousSender,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(theme, message.status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message.status.value,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _statusColor(theme, message.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
