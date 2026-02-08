import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin_message.dart';
import '../../provider/firestore_provider.dart';
import '../../provider/message_thread_provider.dart';
import '../../services/message_sync_service.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/sync_status_badge.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';

/// Message threading screen: chat-style bubbles, timestamps, read status,
/// typing indicators, scroll to latest, input with 500-char limit and encryption indicator.
class MessageThreadScreen extends StatefulWidget {
  const MessageThreadScreen({
    super.key,
    required this.conversationId,
    this.initialMessage,
  });

  final String conversationId;
  final AdminMessage? initialMessage;

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  static const int _maxChars = 500;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({int delay = 0}) {
    void doScroll() {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (delay > 0) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) doScroll();
      });
    } else {
      doScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MessageThreadProvider>(
      create: (context) {
        final firestore = context.read<FirestoreProvider>().firestore;
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final syncService = MessageSyncService(
          firestore: firestore,
          currentUserId: uid,
          isAdmin: () => !(FirebaseAuth.instance.currentUser?.isAnonymous ?? true),
        );
        final p = MessageThreadProvider(
          firestore: firestore,
          conversationId: widget.conversationId,
          currentUserIsAdmin: true,
          currentAdminUid: uid.isEmpty ? null : uid,
          syncService: syncService,
        );
        p.startListening();
        return p;
      },
      child: _MessageThreadBody(
        scrollController: _scrollController,
        inputController: _inputController,
        maxChars: _maxChars,
        onScrollToBottom: _scrollToBottom,
      ),
    );
  }
}

class _MessageThreadBody extends StatefulWidget {
  const _MessageThreadBody({
    required this.scrollController,
    required this.inputController,
    required this.maxChars,
    required this.onScrollToBottom,
  });

  final ScrollController scrollController;
  final TextEditingController inputController;
  final int maxChars;
  final void Function({int delay}) onScrollToBottom;

  @override
  State<_MessageThreadBody> createState() => _MessageThreadBodyState();
}

class _MessageThreadBodyState extends State<_MessageThreadBody> {
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onScrollToBottom(delay: 300);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messageThreadTitle),
      ),
      body: Column(
        children: [
          Consumer<MessageThreadProvider>(
            builder: (context, provider, _) {
              if (!provider.isOffline) return const SizedBox.shrink();
              return OfflineIndicator(isOffline: true);
            },
          ),
          Expanded(
            child: Consumer<MessageThreadProvider>(
              builder: (context, provider, _) {
                if (provider.hasError && provider.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.errorLoading,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => provider.startListening(),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (provider.isLoading && provider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final syncedList = provider.syncedMessages;
                final messages = provider.messages;
                final typing = provider.typing;
                final count = messages.length;

                if (count > _lastMessageCount) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onScrollToBottom();
                  });
                }
                _lastMessageCount = count;

                return ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: count + (typing.anyoneTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == count) {
                      final label = typing.adminTyping
                          ? l10n.adminTyping
                          : l10n.anonymousTyping;
                      return TypingIndicator(label: label);
                    }
                    final message = messages[index];
                    final timeStr = formatMessageTime(message.timestamp, locale);
                    final readLabel = message.status == MessageStatus.read
                        ? l10n.readStatusRead
                        : l10n.readStatusDelivered;
                    final semanticsLabel = message.isFromAdmin
                        ? l10n.messageFromYou
                        : l10n.messageFromAnonymous;
                    final syncStatus = index < syncedList.length
                        ? syncedList[index].syncStatus
                        : null;
                    final showSyncBadge = message.isFromAdmin && syncStatus != null;

                    final bubble = MessageBubble(
                      message: message,
                      timeFormatted: timeStr,
                      readStatusLabel: readLabel,
                      semanticsLabel: semanticsLabel,
                      isEncrypted: message.encryptedContent.isNotEmpty,
                    );

                    if (showSyncBadge) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SyncStatusBadge(status: syncStatus, size: 16),
                            const SizedBox(width: 4),
                            bubble,
                          ],
                        ),
                      );
                    }
                    return bubble;
                  },
                );
              },
            ),
          ),
          _EncryptionIndicator(label: l10n.encryptionActive),
          _MessageInput(
            controller: widget.inputController,
            maxChars: widget.maxChars,
            onScrollToBottom: () => widget.onScrollToBottom(),
          ),
        ],
      ),
    );
  }
}

class _EncryptionIndicator extends StatelessWidget {
  const _EncryptionIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  const _MessageInput({
    required this.controller,
    required this.maxChars,
    required this.onScrollToBottom,
  });

  final TextEditingController controller;
  final int maxChars;
  final VoidCallback onScrollToBottom;

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  Timer? _typingDebounce;
  bool _lastTypingSent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _sendTyping(false);
    widget.controller.removeListener(_onInputChanged);
    super.dispose();
  }

  void _onInputChanged() {
    _typingDebounce?.cancel();
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      _sendTyping(false);
      return;
    }
    _sendTyping(true);
    _typingDebounce = Timer(const Duration(milliseconds: 800), () {
      _sendTyping(false);
    });
  }

  void _sendTyping(bool value) {
    if (_lastTypingSent == value) return;
    _lastTypingSent = value;
    final provider = context.read<MessageThreadProvider>();
    provider.setTyping(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    label: l10n.typeMessageHint,
                    child: TextField(
                      controller: widget.controller,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: widget.maxChars,
                      decoration: InputDecoration(
                        hintText: l10n.typeMessageHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        filled: true,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _send(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<MessageThreadProvider>(
                  builder: (context, provider, _) {
                    final len = widget.controller.text.trim().length;
                    final empty = len == 0;
                    final sending = provider.sending;

                    return Semantics(
                      label: l10n.send,
                      button: true,
                      enabled: !empty && !sending,
                      child: FilledButton(
                        onPressed: (empty || sending)
                            ? null
                            : () => _send(context),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          shape: const CircleBorder(),
                        ),
                        child: sending
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    );
                  },
                ),
              ],
            ),
            Consumer<MessageThreadProvider>(
              builder: (context, provider, _) {
                final len = widget.controller.text.length;
                final nearLimit = len >= widget.maxChars * 0.9;

                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Semantics(
                        label: '${l10n.characterCount}: $len / ${widget.maxChars}',
                        child: Text(
                          '$len / ${widget.maxChars}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: nearLimit
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(BuildContext context) async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<MessageThreadProvider>();
    try {
      await provider.sendMessage(plainText: text);
      widget.controller.clear();
      widget.onScrollToBottom();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).threadErrorSend),
          action: SnackBarAction(
            label: AppLocalizations.of(context).retry,
            onPressed: () => _send(context),
          ),
        ),
      );
    }
  }
}

