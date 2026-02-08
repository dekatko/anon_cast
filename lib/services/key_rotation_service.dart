import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/rotation_event.dart';
import '../models/rotation_metadata.dart';
import '../utils/encryption_util.dart';
import 'key_manager.dart';

/// Rotation policy: rotate every [rotationIntervalDays] days or after [messageCountThreshold] messages.
class RotationPolicy {
  const RotationPolicy({
    this.rotationIntervalDays = 30,
    this.messageCountThreshold = 10000,
  });

  final int rotationIntervalDays;
  final int messageCountThreshold;
}

/// Result of checking whether rotation is needed for a conversation.
class RotationCheckResult {
  final String conversationId;
  final bool needed;
  final String reason;
  final int? messageCount;
  final DateTime? lastRotatedAt;

  const RotationCheckResult({
    required this.conversationId,
    required this.needed,
    required this.reason,
    this.messageCount,
    this.lastRotatedAt,
  });
}

/// Progress reported during re-encryption (for UI or logging).
class RotationProgress {
  final String conversationId;
  final int messagesProcessed;
  final int messagesTotal;

  const RotationProgress(this.conversationId, this.messagesProcessed, this.messagesTotal);
}

/// Exception thrown when key rotation fails.
class KeyRotationException implements Exception {
  final String message;
  final String? conversationId;
  final Object? cause;

  const KeyRotationException(this.message, {this.conversationId, this.cause});

  @override
  String toString() =>
      'KeyRotationException: $message${conversationId != null ? ' (conversationId: $conversationId)' : ''}${cause != null ? ' | cause: $cause' : ''}';
}

/// Service that rotates encryption keys per conversation: checks policy,
/// re-encrypts messages with a new key, keeps old key for rollback, and logs events.
class KeyRotationService {
  KeyRotationService({
    required KeyManager keyManager,
    Box<ChatSession>? chatSessionBox,
    Logger? logger,
    RotationPolicy policy = const RotationPolicy(),
  })  : _keyManager = keyManager,
        _chatSessionBox = chatSessionBox ?? Hive.box<ChatSession>('chat_sessions'),
        _log = logger ?? Logger(),
        _policy = policy;

  final KeyManager _keyManager;
  final Box<ChatSession> _chatSessionBox;
  final Logger _log;
  final RotationPolicy _policy;

  /// Storage for rotation metadata (lastRotatedAt, messageCountAtRotation).
  /// Uses the same backend as KeyManager; we need to pass a way to read/write.
  /// KeyManager doesn't expose raw storage, so we'll use a separate simple store.
  /// For now we use a static map keyed by conversationId (in-memory). In production
  /// you would use secure storage or Hive for this. We'll add a metadata delegate.
  final Map<String, RotationMetadata> _metadataStore = {};

  /// Events for admin dashboard. In production, persist to Firestore or local DB.
  final List<RotationEvent> _eventLog = [];
  static const int _maxEventLogSize = 500;

  /// Optional: inject metadata storage (e.g. read/write from secure storage).
  /// If not set, uses in-memory [_metadataStore].
  void setMetadataStorage({
    required Future<RotationMetadata?> Function(String) read,
    required Future<void> Function(String, RotationMetadata) write,
  }) {
    _metaRead = read;
    _metaWrite = write;
  }

  Future<RotationMetadata?> Function(String) _metaRead =
      (String _) async => null;
  Future<void> Function(String, RotationMetadata) _metaWrite =
      (String _, RotationMetadata __) async {};

  /// Returns whether rotation is needed for [conversationId] and why.
  Future<RotationCheckResult> checkIfRotationNeeded(String conversationId) async {
    final session = _chatSessionBox.get(conversationId);
    final messageCount = session?.messages.length ?? 0;

    final meta = await _getMetadata(conversationId);
    final lastRotatedAt = meta?.lastRotatedAt;
    final countAtRotation = meta?.messageCountAtRotation ?? 0;
    final messagesSinceRotation = messageCount - countAtRotation;

    if (lastRotatedAt == null) {
      return RotationCheckResult(
        conversationId: conversationId,
        needed: messageCount >= _policy.messageCountThreshold,
        reason: messageCount >= _policy.messageCountThreshold
            ? 'Message count $messageCount >= ${_policy.messageCountThreshold}'
            : 'No previous rotation; under message threshold',
        messageCount: messageCount,
      );
    }

    final daysSince = DateTime.now().difference(lastRotatedAt).inDays;
    final dueToTime = daysSince >= _policy.rotationIntervalDays;
    final dueToCount = messagesSinceRotation >= _policy.messageCountThreshold;

    if (dueToTime && dueToCount) {
      return RotationCheckResult(
        conversationId: conversationId,
        needed: true,
        reason:
            'Both: $daysSince days since rotation and $messagesSinceRotation messages since rotation',
        messageCount: messageCount,
        lastRotatedAt: lastRotatedAt,
      );
    }
    if (dueToTime) {
      return RotationCheckResult(
        conversationId: conversationId,
        needed: true,
        reason: '$daysSince days since last rotation (>= ${_policy.rotationIntervalDays})',
        messageCount: messageCount,
        lastRotatedAt: lastRotatedAt,
      );
    }
    if (dueToCount) {
      return RotationCheckResult(
        conversationId: conversationId,
        needed: true,
        reason:
            'Message count since rotation $messagesSinceRotation >= ${_policy.messageCountThreshold}',
        messageCount: messageCount,
        lastRotatedAt: lastRotatedAt,
      );
    }

    return RotationCheckResult(
      conversationId: conversationId,
      needed: false,
      reason: 'Within policy (${_policy.rotationIntervalDays}d, ${_policy.messageCountThreshold} msgs)',
      messageCount: messageCount,
      lastRotatedAt: lastRotatedAt,
    );
  }

  /// Rotates the key for [conversationId]: generates new key, re-encrypts all
  /// messages, updates current version, keeps old key for rollback. On failure, rolls back.
  /// [onProgress] is called with (processed, total) for UI.
  Future<void> rotateKey(
    String conversationId, {
    void Function(RotationProgress)? onProgress,
  }) async {
    _addEvent(RotationEvent(
      conversationId: conversationId,
      type: RotationEventType.started,
      at: DateTime.now(),
      message: 'Key rotation started',
    ));

    ChatSession? session = _chatSessionBox.get(conversationId);
    if (session == null) {
      _addEvent(RotationEvent(
        conversationId: conversationId,
        type: RotationEventType.failed,
        at: DateTime.now(),
        message: 'No session found',
        error: 'Session not in box',
      ));
      throw KeyRotationException(
        'No chat session found for conversation.',
        conversationId: conversationId,
      );
    }

    final currentVersion = await _keyManager.getCurrentKeyVersion(conversationId) ?? 0;
    final oldKey = await _keyManager.retrieveKeyWithVersion(
        conversationId, currentVersion);
    if (oldKey == null) {
      _addEvent(RotationEvent(
        conversationId: conversationId,
        type: RotationEventType.failed,
        at: DateTime.now(),
        message: 'No current key found',
        error: 'Cannot rotate without existing key',
      ));
      throw KeyRotationException(
        'No current key to rotate from.',
        conversationId: conversationId,
      );
    }

    final newVersion = currentVersion + 1;
    final newKey = _keyManager.generateKey();
    final snapshot = _cloneSession(session);

    try {
      await _keyManager.storeKeyWithVersion(
          conversationId, newVersion, newKey);
      final reEncrypted = await _reEncryptMessages(
        session,
        oldKey: oldKey,
        newKey: newKey,
        onProgress: (p, t) {
          onProgress?.call(RotationProgress(conversationId, p, t));
          _addEvent(RotationEvent(
            conversationId: conversationId,
            type: RotationEventType.progress,
            at: DateTime.now(),
            message: 'Re-encrypting messages',
            messagesProcessed: p,
            messagesTotal: t,
          ));
        },
      );
      final newSession = ChatSession(
        id: session.id,
        studentId: session.studentId,
        adminId: session.adminId,
        startedAt: session.startedAt,
        lastActive: session.lastActive,
        messages: reEncrypted,
      );
      _chatSessionBox.put(conversationId, newSession);
      await _keyManager.setCurrentKeyVersion(conversationId, newVersion);

      final meta = RotationMetadata(
        conversationId: conversationId,
        lastRotatedAt: DateTime.now(),
        messageCountAtRotation: newSession.messages.length,
      );
      await _setMetadata(conversationId, meta);

      _addEvent(RotationEvent(
        conversationId: conversationId,
        type: RotationEventType.completed,
        at: DateTime.now(),
        message: 'Key rotation completed',
        messagesProcessed: reEncrypted.length,
        messagesTotal: reEncrypted.length,
      ));
      _log.i('Key rotation completed for $conversationId -> v$newVersion');
    } catch (e, st) {
      _log.e('Key rotation failed, rolling back', error: e, stackTrace: st);
      _addEvent(RotationEvent(
        conversationId: conversationId,
        type: RotationEventType.failed,
        at: DateTime.now(),
        message: 'Rotation failed',
        error: e.toString(),
      ));
      _chatSessionBox.put(conversationId, snapshot);
      await _keyManager.setCurrentKeyVersion(conversationId, currentVersion);
      _addEvent(RotationEvent(
        conversationId: conversationId,
        type: RotationEventType.rolledBack,
        at: DateTime.now(),
        message: 'Rolled back to previous key version',
      ));
      throw KeyRotationException(
        'Rotation failed: $e',
        conversationId: conversationId,
        cause: e,
      );
    }
  }

  /// Returns all conversation IDs that have sessions in the box.
  List<String> getConversationIds() {
    return _chatSessionBox.keys.map((k) => k.toString()).toList();
  }

  /// Checks all conversations and rotates those that need it. Returns count rotated.
  Future<int> checkAndRotateAll({
    void Function(RotationProgress)? onProgress,
  }) async {
    int rotated = 0;
    for (final id in getConversationIds()) {
      final result = await checkIfRotationNeeded(id);
      if (result.needed) {
        try {
          await rotateKey(id, onProgress: onProgress);
          rotated++;
        } catch (e) {
          _log.w('Rotation skipped for $id', error: e);
        }
      }
    }
    return rotated;
  }

  /// Returns recent rotation events for admin dashboard.
  List<RotationEvent> getRecentEvents({int limit = 100}) {
    final from = _eventLog.length - limit;
    return _eventLog.sublist(from < 0 ? 0 : from);
  }

  /// Returns rotation status for admin: per-conversation and global.
  Future<RotationStatus> getRotationStatus() async {
    final conversations = <ConversationRotationStatus>[];
    for (final id in getConversationIds()) {
      final check = await checkIfRotationNeeded(id);
      final meta = await _getMetadata(id);
      conversations.add(ConversationRotationStatus(
        conversationId: id,
        messageCount: check.messageCount ?? 0,
        lastRotatedAt: meta?.lastRotatedAt,
        rotationNeeded: check.needed,
        reason: check.reason,
      ));
    }
    return RotationStatus(
      conversations: conversations,
      recentEvents: getRecentEvents(limit: 50),
    );
  }

  Future<RotationMetadata?> _getMetadata(String conversationId) async {
    final custom = await _metaRead(conversationId);
    if (custom != null) return custom;
    return _metadataStore[conversationId];
  }

  Future<void> _setMetadata(
      String conversationId, RotationMetadata meta) async {
    _metadataStore[conversationId] = meta;
    await _metaWrite(conversationId, meta);
  }

  void _addEvent(RotationEvent event) {
    _eventLog.add(event);
    if (_eventLog.length > _maxEventLogSize) {
      _eventLog.removeRange(0, _eventLog.length - _maxEventLogSize);
    }
  }

  ChatSession _cloneSession(ChatSession s) {
    return ChatSession(
      id: s.id,
      studentId: s.studentId,
      adminId: s.adminId,
      startedAt: s.startedAt,
      lastActive: s.lastActive,
      messages: List.from(s.messages),
    );
  }

  Future<List<ChatMessage>> _reEncryptMessages(
    ChatSession session, {
    required Uint8List oldKey,
    required Uint8List newKey,
    void Function(int processed, int total)? onProgress,
  }) async {
    final out = <ChatMessage>[];
    final total = session.messages.length;
    for (var i = 0; i < total; i++) {
      final msg = session.messages[i];
      try {
        final iv = msg.iv ?? Uint8List(16);
        if (iv.length != 16) {
          throw KeyRotationException(
            'Invalid IV length for message ${msg.id}',
            conversationId: session.id,
          );
        }
        final plain = EncryptionUtil.decryptWithKeyBytes(
            msg.encryptedContent, oldKey, iv);
        final newIv = EncryptionUtil.generateRandomBytes(16);
        final encrypted =
            EncryptionUtil.encryptWithKeyBytes(plain, newKey, newIv);
        out.add(ChatMessage(
          id: msg.id,
          senderId: msg.senderId,
          encryptedContent: encrypted,
          timestamp: msg.timestamp,
          iv: newIv,
        ));
      } catch (e) {
        throw KeyRotationException(
          'Re-encrypt failed for message ${msg.id}: $e',
          conversationId: session.id,
          cause: e,
        );
      }
      onProgress?.call(i + 1, total);
    }
    return out;
  }
}

/// Per-conversation rotation status for admin UI.
class ConversationRotationStatus {
  final String conversationId;
  final int messageCount;
  final DateTime? lastRotatedAt;
  final bool rotationNeeded;
  final String reason;

  const ConversationRotationStatus({
    required this.conversationId,
    required this.messageCount,
    this.lastRotatedAt,
    required this.rotationNeeded,
    required this.reason,
  });
}

/// Full rotation status for admin dashboard.
class RotationStatus {
  final List<ConversationRotationStatus> conversations;
  final List<RotationEvent> recentEvents;

  const RotationStatus({
    required this.conversations,
    required this.recentEvents,
  });
}
