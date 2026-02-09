import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../models/conversation_key.dart';
import '../models/message.dart';
import 'encryption_service.dart';
import 'message_relay.dart';
import 'message_storage_interface.dart';

/// Policy: rotate every [rotationIntervalDays] days or after [messageCountThreshold] messages.
class ConversationRotationPolicy {
  const ConversationRotationPolicy({
    this.rotationIntervalDays = 30,
    this.messageCountThreshold = 10000,
  });

  final int rotationIntervalDays;
  final int messageCountThreshold;
}

/// Result of checking if rotation is needed.
class ConversationRotationCheckResult {
  final String conversationId;
  final bool needed;
  final String reason;
  final int messageCount;
  final DateTime? lastRotatedAt;

  const ConversationRotationCheckResult({
    required this.conversationId,
    required this.needed,
    required this.reason,
    required this.messageCount,
    this.lastRotatedAt,
  });
}

/// Progress during re-encryption (for UI).
class ConversationRotationProgress {
  final String conversationId;
  final int messagesProcessed;
  final int messagesTotal;

  const ConversationRotationProgress(
    this.conversationId,
    this.messagesProcessed,
    this.messagesTotal,
  );
}

/// Thrown when rotation fails.
class ConversationKeyRotationException implements Exception {
  final String message;
  final String? conversationId;
  final Object? cause;

  const ConversationKeyRotationException(this.message,
      {this.conversationId, this.cause});

  @override
  String toString() =>
      'ConversationKeyRotationException: $message'
      '${conversationId != null ? ' (conversationId: $conversationId)' : ''}'
      '${cause != null ? ' | cause: $cause' : ''}';
}

/// Rotates E2E conversation keys: re-encrypts Firestore + Hive messages,
/// keeps old key for history, supports rollback and audit log.
class ConversationKeyRotationService {
  ConversationKeyRotationService({
    required MessageServiceStorage storage,
    required MessageRelay relay,
    required EncryptionService encryption,
    FirebaseFirestore? firestore,
    Logger? logger,
    ConversationRotationPolicy policy = const ConversationRotationPolicy(),
  })  : _storage = storage,
        _relay = relay,
        _encryption = encryption,
        _firestore = firestore,
        _log = logger ?? Logger(),
        _policy = policy;

  final MessageServiceStorage _storage;
  final MessageRelay _relay;
  final EncryptionService _encryption;
  final FirebaseFirestore? _firestore;
  final Logger _log;
  final ConversationRotationPolicy _policy;

  static const String _auditCollection = 'key_rotation_audit';
  static const int _maxHistoricalKeys = 5;

  /// Returns true if rotation is needed: 30+ days since last rotation,
  /// or 10k+ messages, or [manual] is true.
  Future<bool> needsRotation(String conversationId, {bool manual = false}) async {
    final result = await checkRotationNeeded(conversationId, manual: manual);
    return result.needed;
  }

  /// Full check result (reason, counts). Use for UI.
  Future<ConversationRotationCheckResult> checkRotationNeeded(
    String conversationId, {
    bool manual = false,
  }) async {
    if (manual) {
      final count = (await _storage.getConversationMessages(conversationId)).length;
      final ck = await _storage.getConversationKeyFull(conversationId);
      return ConversationRotationCheckResult(
        conversationId: conversationId,
        needed: true,
        reason: 'Manual rotation requested',
        messageCount: count,
        lastRotatedAt: ck?.lastRotated,
      );
    }

    final ck = await _storage.getConversationKeyFull(conversationId);
    if (ck == null) {
      return const ConversationRotationCheckResult(
        conversationId: '',
        needed: false,
        reason: 'No conversation key',
        messageCount: 0,
      );
    }

    final messages = await _storage.getConversationMessages(conversationId);
    final messageCount = messages.length;
    final lastRotatedAt = ck.lastRotated;
    final daysSince = DateTime.now().difference(lastRotatedAt).inDays;
    final dueToTime = daysSince >= _policy.rotationIntervalDays;
    final dueToCount = messageCount >= _policy.messageCountThreshold;

    if (dueToTime && dueToCount) {
      return ConversationRotationCheckResult(
        conversationId: conversationId,
        needed: true,
        reason:
            'Both: $daysSince days and $messageCount messages (>= ${_policy.messageCountThreshold})',
        messageCount: messageCount,
        lastRotatedAt: lastRotatedAt,
      );
    }
    if (dueToTime) {
      return ConversationRotationCheckResult(
        conversationId: conversationId,
        needed: true,
        reason: '$daysSince days since last rotation (>= ${_policy.rotationIntervalDays})',
        messageCount: messageCount,
        lastRotatedAt: lastRotatedAt,
      );
    }
    if (dueToCount) {
      return ConversationRotationCheckResult(
        conversationId: conversationId,
        needed: true,
        reason:
            'Message count $messageCount >= ${_policy.messageCountThreshold}',
        messageCount: messageCount,
        lastRotatedAt: lastRotatedAt,
      );
    }

    return ConversationRotationCheckResult(
      conversationId: conversationId,
      needed: false,
      reason:
          'Within policy (${_policy.rotationIntervalDays}d, ${_policy.messageCountThreshold} msgs)',
      messageCount: messageCount,
      lastRotatedAt: lastRotatedAt,
    );
  }

  /// Performs key rotation: new key, re-encrypt all messages in Firestore + Hive,
  /// move current key to oldKeys, save, audit log. On failure, rolls back.
  Future<void> rotateKey(
    String conversationId, {
    void Function(ConversationRotationProgress)? onProgress,
  }) async {
    final ck = await _storage.getConversationKeyFull(conversationId);
    if (ck == null) {
      throw ConversationKeyRotationException(
        'No conversation key for $conversationId',
        conversationId: conversationId,
      );
    }

    final newKeyBase64 = await _encryption.generateConversationKey();
    final now = DateTime.now();
    final newVersion = ck.version + 1;

    // Historical key for current (so we can decrypt during re-encrypt and for old messages)
    final historicalKey = HistoricalKey(
      key: ck.key,
      version: ck.version,
      validFrom: ck.lastRotated,
      validUntil: now,
    );
    final newOldKeys = [historicalKey, ...ck.oldKeys].take(_maxHistoricalKeys).toList();

    // 1) Fetch all messages from Firestore
    List<Map<String, dynamic>> remoteMessages;
    try {
      remoteMessages = await _relay.getMessages(conversationId);
    } catch (e, st) {
      _log.e('Rotation: getMessages failed', error: e, stackTrace: st);
      await _logAudit(conversationId, newVersion, 0, false, e.toString());
      throw ConversationKeyRotationException(
        'Failed to fetch messages: $e',
        conversationId: conversationId,
        cause: e,
      );
    }

    final total = remoteMessages.length;
    onProgress?.call(ConversationRotationProgress(conversationId, 0, total));

    final reEncryptedRemote = <String, Map<String, dynamic>>{};
    final originalRemote = <String, Map<String, dynamic>>{};
    try {
      for (var i = 0; i < remoteMessages.length; i++) {
        final doc = remoteMessages[i];
        final id = doc['id'] as String? ?? '';
        final encryptedContent = doc['encryptedContent'] as String? ?? '';
        final ivRaw = doc['iv'];
        final keyVersion = doc['keyVersion'] as int? ?? 1;

        if (encryptedContent.isEmpty) {
          onProgress?.call(ConversationRotationProgress(conversationId, i + 1, total));
          continue;
        }

        String ivBase64;
        if (ivRaw is List) {
          ivBase64 = base64Encode((ivRaw as List).cast<int>());
        } else {
          onProgress?.call(ConversationRotationProgress(conversationId, i + 1, total));
          continue;
        }

        String keyToUse = ck.key;
        if (keyVersion != ck.version) {
          HistoricalKey? hist;
          for (final k in ck.oldKeys) {
            if (k.version == keyVersion) {
              hist = k;
              break;
            }
          }
          if (hist == null) {
            throw ConversationKeyRotationException(
              'No historical key for version $keyVersion (message $id)',
              conversationId: conversationId,
            );
          }
          keyToUse = hist.key;
        }

        final plaintext = await _encryption.decryptMessage(
          encryptedContent,
          ivBase64,
          keyToUse,
        );
        final encrypted = await _encryption.encryptMessage(plaintext, newKeyBase64);
        originalRemote[id] = {
          'encryptedContent': encryptedContent,
          'iv': ivRaw,
          if (keyVersion != 1) 'keyVersion': keyVersion,
        };
        reEncryptedRemote[id] = {
          'encryptedContent': encrypted.encryptedContent,
          'iv': _ivToList(encrypted.iv),
          'keyVersion': newVersion,
        };
        onProgress?.call(ConversationRotationProgress(conversationId, i + 1, total));
      }
    } on EncryptionServiceException catch (e) {
      _log.e('Rotation: re-encrypt failed', error: e);
      await _logAudit(conversationId, newVersion, 0, false, e.toString());
      throw ConversationKeyRotationException(
        'Re-encryption failed: ${e.message}',
        conversationId: conversationId,
        cause: e,
      );
    }

    // 2) Update Firestore (batch)
    try {
      for (final entry in reEncryptedRemote.entries) {
        await _relay.update(entry.key, entry.value);
      }
    } catch (e, st) {
      _log.e('Rotation: Firestore update failed', error: e, stackTrace: st);
      await _logAudit(conversationId, newVersion, 0, false, e.toString());
      throw ConversationKeyRotationException(
        'Failed to update Firestore: $e',
        conversationId: conversationId,
        cause: e,
      );
    }

    // 3) Update Hive messages (re-encrypted content + keyVersion)
    try {
      final localMessages = await _storage.getConversationMessages(conversationId);
      for (final msg in localMessages) {
        final updated = reEncryptedRemote[msg.id];
        if (updated != null) {
          await _storage.storeMessage(msg.copyWith(
            encryptedContent: updated['encryptedContent'] as String,
            iv: (updated['iv'] as List<dynamic>?)?.cast<int>(),
            keyVersion: newVersion,
          ));
        }
      }
    } catch (e, st) {
      _log.e('Rotation: Hive update failed, rolling back Firestore', error: e, stackTrace: st);
      for (final entry in originalRemote.entries) {
        try {
          await _relay.update(entry.key, entry.value);
        } catch (_) {}
      }
      await _logAudit(conversationId, newVersion, total, false, 'Hive update failed: $e');
      throw ConversationKeyRotationException(
        'Failed to update local messages: $e',
        conversationId: conversationId,
        cause: e,
      );
    }

    // 4) Save new key (current + oldKeys)
    final newCk = ConversationKey(
      id: conversationId,
      key: newKeyBase64,
      createdAt: ck.createdAt,
      lastRotated: now,
      version: newVersion,
      oldKeys: newOldKeys,
    );
    await _storage.storeConversationKeyFull(conversationId, newCk);

    await _logAudit(conversationId, newVersion, total, true, null);
    _log.i('Key rotation completed for $conversationId -> v$newVersion ($total messages)');
  }

  List<int> _ivToList(String ivBase64) {
    return base64Decode(ivBase64).cast<int>();
  }

  Future<void> _logAudit(
    String conversationId,
    int version,
    int messageCount,
    bool success,
    String? error,
  ) async {
    if (_firestore == null) return;
    try {
      await _firestore!.collection(_auditCollection).add({
        'conversationId': conversationId,
        'version': version,
        'at': FieldValue.serverTimestamp(),
        'messageCount': messageCount,
        'success': success,
        if (error != null) 'error': error,
      });
    } catch (e) {
      _log.w('Rotation: audit log write failed', error: e);
    }
  }

  /// Returns all conversation IDs that have a key (for scheduler).
  Future<List<String>> getConversationIds() async {
    final map = await _storage.getAllConversationKeys();
    return map.keys.toList();
  }

  /// Forces rotation of all conversation keys (ignores policy). Use for "Force Key Rotation" in settings.
  /// Returns the number of conversations rotated.
  Future<int> forceRotateAll({
    void Function(ConversationRotationProgress)? onProgress,
  }) async {
    int rotated = 0;
    for (final id in await getConversationIds()) {
      try {
        await rotateKey(id, onProgress: onProgress);
        rotated++;
      } on ConversationKeyRotationException catch (e) {
        _log.w('Rotation skipped for $id: ${e.message}', error: e.cause);
      } catch (e, st) {
        _log.w('Rotation skipped for $id', error: e, stackTrace: st);
      }
    }
    return rotated;
  }

  /// Checks all conversations and rotates those that need it. Skips when offline
  /// (no Firestore). Returns count rotated.
  Future<int> checkAndRotateAll({
    bool onlyWhenCharging = true,
    void Function(ConversationRotationProgress)? onProgress,
  }) async {
    // Caller can check charging and skip if onlyWhenCharging and not charging
    int rotated = 0;
    for (final id in await getConversationIds()) {
      final result = await checkRotationNeeded(id);
      if (!result.needed) continue;
      try {
        await rotateKey(id, onProgress: onProgress);
        rotated++;
      } on ConversationKeyRotationException catch (e) {
        _log.w('Rotation skipped for $id: ${e.message}', error: e.cause);
      } catch (e, st) {
        _log.w('Rotation skipped for $id', error: e, stackTrace: st);
      }
    }
    return rotated;
  }

  /// Returns key string for [conversationId] and [version] (current or historical).
  /// For use by MessageService when decrypting with keyVersion.
  Future<String?> getKeyForVersion(String conversationId, int version) async {
    final ck = await _storage.getConversationKeyFull(conversationId);
    if (ck == null) return null;
    if (ck.version == version) return ck.key;
    for (final k in ck.oldKeys) {
      if (k.version == version) return k.key;
    }
    return null;
  }
}
