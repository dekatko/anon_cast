import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/rotation_event.dart';
import '../services/key_manager.dart';
import '../services/key_rotation_service.dart';
import '../services/rotation_scheduler.dart';

/// Admin screen: key rotation status, recent events, and manual "Check / Rotate now".
class AdminRotationStatusScreen extends StatefulWidget {
  const AdminRotationStatusScreen({super.key});

  @override
  State<AdminRotationStatusScreen> createState() =>
      _AdminRotationStatusScreenState();
}

class _AdminRotationStatusScreenState extends State<AdminRotationStatusScreen> {
  final KeyManager _keyManager = KeyManager(logger: Logger());
  late final KeyRotationService _rotationService;
  RotationStatus? _status;
  bool _loading = true;
  String? _error;
  bool _rotating = false;
  String? _progressText;

  @override
  void initState() {
    super.initState();
    _rotationService = KeyRotationService(
      keyManager: _keyManager,
      logger: Logger(),
    );
    _loadStatus();
    _checkBackgroundFlag();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _rotationService.getRotationStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// If background task set the flag, run rotation check and clear flag.
  Future<void> _checkBackgroundFlag() async {
    final requested = await RotationScheduler.isCheckRequested();
    if (requested && mounted) {
      await RotationScheduler.clearCheckRequested();
      await _runRotationCheck();
    }
  }

  Future<void> _runRotationCheck() async {
    if (_rotating) return;
    setState(() {
      _rotating = true;
      _progressText = 'Checking conversations...';
      _error = null;
    });
    try {
      final rotated = await _rotationService.checkAndRotateAll(
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _progressText =
                  '${p.conversationId}: ${p.messagesProcessed}/${p.messagesTotal}';
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _progressText = rotated > 0
              ? 'Rotation complete. Rotated $rotated conversation(s).'
              : 'Check complete. No rotation needed.';
          _rotating = false;
        });
        await _loadStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _progressText = null;
          _rotating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _keyManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Key Rotation'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ),
            if (_progressText != null)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                    if (_rotating) const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_progressText!)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loading || _rotating
                  ? null
                  : () async {
                      await _runRotationCheck();
                    },
              icon: _rotating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_rotating ? 'Rotating...' : 'Check & rotate now'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rotation policy: every 30 days or after 10,000 messages.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_status != null) ...[
              const Text(
                'Conversations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              ..._status!.conversations.map((c) => _ConversationTile(
                    status: c,
                    onRotate: () async {
                      await _rotationService.rotateKey(c.conversationId,
                          onProgress: (p) {
                        if (mounted) {
                          setState(() {
                            _progressText =
                                '${p.messagesProcessed}/${p.messagesTotal}';
                          });
                        }
                      });
                      await _loadStatus();
                    },
                  )),
              if (_status!.conversations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No conversations yet.'),
                ),
              const SizedBox(height: 24),
              const Text(
                'Recent events',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              ..._status!.recentEvents.reversed.take(20).map((e) => _EventTile(event: e)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationRotationStatus status;
  final VoidCallback onRotate;

  const _ConversationTile({
    required this.status,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          status.conversationId,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Messages: ${status.messageCount}'
          '${status.lastRotatedAt != null ? " · Last rotated: ${status.lastRotatedAt!.toIso8601String().split('T').first}" : ""}\n'
          '${status.rotationNeeded ? "⚠ ${status.reason}" : status.reason}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: status.rotationNeeded
            ? TextButton(
                onPressed: onRotate,
                child: const Text('Rotate'),
              )
            : null,
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final RotationEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (event.type) {
      case RotationEventType.completed:
      case RotationEventType.rolledBack:
        color = Colors.green;
        break;
      case RotationEventType.failed:
        color = Colors.red;
        break;
      case RotationEventType.started:
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${event.at.toIso8601String().split('T').join(' ').substring(0, 19)} '
              '[${event.type.name}] ${event.conversationId}: ${event.message}'
              '${event.messagesProcessed != null ? " (${event.messagesProcessed}/${event.messagesTotal})" : ""}'
              '${event.error != null ? " — ${event.error}" : ""}',
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
