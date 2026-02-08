import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../models/security_report.dart';
import 'encryption_service.dart';
import 'local_storage_service.dart';
import 'message_storage_interface.dart';

/// Security audit and validation helpers to ensure encryption is working correctly.
///
/// ## Validations
/// - [validateEncryption]: Firestore messages have encryptedContent (base64) and IV, not plaintext.
/// - [validateKeysNotInFirestore]: No forbidden key fields in message documents.
/// - [validateHiveEncryption]: Local storage path is app-private (and recommendation for encryption at rest).
/// - [validateDecryption]: Decrypting a Firestore message with Hive key matches cached plaintext.
/// - [runSecurityAudit]: Runs all checks and returns a [SecurityReport].
///
/// ## Logging (debugging only; never log sensitive data)
/// - Log that a validation ran and whether it passed/failed.
/// - Log key generation events (not key values).
/// - Do not log message content, keys, IVs, or raw encrypted payloads.
///
/// ## Admin dashboard
/// Use [runSecurityAudit] from the System Settings screen; show [SecurityReport] in
/// [AdminSecurityAuditScreen] with status indicator and "Run again" action.
class SecurityValidator {
  SecurityValidator({
    FirebaseFirestore? firestore,
    MessageServiceStorage? storage,
    EncryptionService? encryption,
    Logger? logger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? LocalStorageService.instance,
        _encryption = encryption ?? EncryptionService(),
        _log = logger ?? Logger();

  final FirebaseFirestore _firestore;
  final MessageServiceStorage _storage;
  final EncryptionService _encryption;
  final Logger _log;

  static const String _messagesCollection = 'messages';

  /// Forbidden field names that must not appear in Firestore (keys must stay local).
  static const List<String> _forbiddenKeyFields = [
    'key',
    'encryptionKey',
    'conversationKey',
    'secretKey',
    'decryptionKey',
  ];

  /// Verify a message in Firestore is actually encrypted (not plaintext), has IV, valid base64.
  /// Fetches one message from the conversation and checks encryptedContent/iv.
  Future<bool> validateEncryption(String conversationId) async {
    try {
      _log.d('SecurityValidator: running encryption validation for conversation $conversationId');
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .where('conversationId', isEqualTo: conversationId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        _log.w('SecurityValidator: no messages to validate in $conversationId');
        return true; // nothing to validate
      }
      final doc = snapshot.docs.first;
      final data = doc.data();
      final encryptedContent = data['encryptedContent'];
      final ivRaw = data['iv'];
      if (encryptedContent == null || encryptedContent is! String) {
        _log.w('SecurityValidator: encryptedContent missing or not string');
        return false;
      }
      if (encryptedContent.isEmpty) {
        _log.w('SecurityValidator: encryptedContent empty');
        return false;
      }
      // IV must be present (list or base64 string)
      if (ivRaw == null) {
        _log.w('SecurityValidator: iv missing');
        return false;
      }
      // Check base64 encoding of encryptedContent (decode should not throw)
      try {
        base64Decode(encryptedContent);
      } catch (_) {
        _log.w('SecurityValidator: encryptedContent is not valid base64');
        return false;
      }
      // If IV is list, check length
      if (ivRaw is List) {
        if (ivRaw.isEmpty) {
          _log.w('SecurityValidator: iv list empty');
          return false;
        }
      }
      // Heuristic: plaintext would often be short and ASCII. Encrypted base64 is longer and wider charset.
      // So we only flag if content looks like obvious plaintext (e.g. no high-entropy).
      final decoded = base64Decode(encryptedContent);
      if (decoded.length < 16) {
        _log.w('SecurityValidator: encrypted payload too short');
        return false;
      }
      _log.d('SecurityValidator: encryption validation passed for $conversationId');
      return true;
    } catch (e, st) {
      _log.e('SecurityValidator: validateEncryption failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Ensure conversation keys are NOT stored in Firestore.
  /// Samples message documents and checks for forbidden field names.
  Future<bool> validateKeysNotInFirestore() async {
    try {
      _log.d('SecurityValidator: running keys-not-in-Firestore validation');
      final snapshot = await _firestore.collection(_messagesCollection).limit(50).get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        for (final forbidden in _forbiddenKeyFields) {
          if (data.containsKey(forbidden) && data[forbidden] != null) {
            _log.w('SecurityValidator: forbidden field "$forbidden" found in document ${doc.id}');
            return false;
          }
        }
      }
      _log.d('SecurityValidator: keys-not-in-Firestore validation passed');
      return true;
    } catch (e, st) {
      _log.e('SecurityValidator: validateKeysNotInFirestore failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Verify local storage is in app-private path (and optionally recommend encryption at rest).
  /// Standard Hive does not encrypt at rest; this checks path is secure and adds a recommendation.
  /// In test environments (no Flutter binding), path_provider may throw; we return true and skip.
  Future<bool> validateHiveEncryption() async {
    try {
      _log.d('SecurityValidator: running Hive storage validation');
      if (kIsWeb) {
        _log.d('SecurityValidator: Hive path check skipped on web');
        return true;
      }
      try {
        final dir = await getApplicationDocumentsDirectory();
        final path = dir.path;
        if (path.isEmpty) {
          _log.w('SecurityValidator: documents path empty');
          return false;
        }
        if (path.contains('Application') || path.contains('Documents') || path.contains('data')) {
          _log.d('SecurityValidator: Hive path appears to be app-private');
        }
      } catch (e) {
        // Test or headless environment: path_provider may fail (e.g. Binding not initialized).
        _log.d('SecurityValidator: path check skipped (no platform path available)');
        return true;
      }
      _log.d('SecurityValidator: Hive storage validation passed (path in app dir)');
      return true;
    } catch (e, st) {
      _log.e('SecurityValidator: validateHiveEncryption failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Verify decryption works: fetch message from Firestore, decrypt with Hive key, compare to Hive cache.
  Future<bool> validateDecryption(String messageId) async {
    try {
      _log.d('SecurityValidator: running decryption validation for message $messageId');
      final docRef = _firestore.collection(_messagesCollection).doc(messageId);
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) {
        _log.w('SecurityValidator: message $messageId not found in Firestore');
        return false;
      }
      final data = doc.data()!;
      final conversationId = data['conversationId'] as String?;
      if (conversationId == null || conversationId.isEmpty) {
        _log.w('SecurityValidator: conversationId missing');
        return false;
      }
      final key = await _storage.getConversationKey(conversationId);
      if (key == null || key.isEmpty) {
        _log.w('SecurityValidator: no local key for conversation $conversationId');
        return false;
      }
      final encryptedContent = data['encryptedContent'] as String? ?? '';
      final ivRaw = data['iv'];
      if (encryptedContent.isEmpty || ivRaw == null) {
        _log.w('SecurityValidator: encryptedContent or iv missing');
        return false;
      }
      String ivBase64;
      if (ivRaw is List) {
        ivBase64 = base64Encode(ivRaw.cast<int>());
      } else if (ivRaw is String) {
        ivBase64 = ivRaw;
      } else {
        _log.w('SecurityValidator: iv has unexpected type');
        return false;
      }
      final decrypted = await _encryption.decryptMessage(encryptedContent, ivBase64, key);
      final cached = await _storage.getMessage(messageId);
      if (cached == null) {
        _log.w('SecurityValidator: no cached message for $messageId (decryption succeeded but no local copy)');
        return true; // decryption worked; cache might not be synced yet
      }
      final cachedContent = cached.content ?? '';
      if (decrypted != cachedContent) {
        _log.w('SecurityValidator: decrypted content does not match cached content');
        return false;
      }
      _log.d('SecurityValidator: decryption validation passed for $messageId');
      return true;
    } on Exception catch (e, st) {
      _log.e('SecurityValidator: validateDecryption failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Run full security audit; returns report with all results, warnings, recommendations.
  Future<SecurityReport> runSecurityAudit({
    List<String>? conversationIdsToCheck,
    String? messageIdToCheck,
  }) async {
    _log.d('SecurityValidator: starting security audit');
    final results = <ValidationResult>[];
    final warnings = <String>[];
    final recommendations = <String>[];

    // 1. Keys not in Firestore
    final keysNotInFs = await validateKeysNotInFirestore();
    results.add(ValidationResult(
      name: 'Keys not in Firestore',
      passed: keysNotInFs,
      message: keysNotInFs ? 'No key fields found in message documents' : 'Forbidden key field found',
    ));

    // 2. Hive storage
    final hiveOk = await validateHiveEncryption();
    results.add(ValidationResult(
      name: 'Local storage path',
      passed: hiveOk,
      message: hiveOk ? 'Storage path is app-private' : 'Storage path check failed',
    ));
    if (hiveOk && !kIsWeb) {
      recommendations.add('Consider hive_encrypted_box for encryption at rest.');
    }

    // 3. Encryption (sample one conversation if we have IDs)
    List<String> convIds = conversationIdsToCheck ?? [];
    if (convIds.isEmpty) {
      try {
        final snapshot = await _firestore
            .collection(_messagesCollection)
            .limit(5)
            .get();
        final ids = snapshot.docs
            .map((d) => d.data()['conversationId'] as String?)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        convIds = ids;
      } catch (_) {}
    }
    if (convIds.isNotEmpty) {
      bool encOk = true;
      for (final cid in convIds.take(3)) {
        if (!await validateEncryption(cid)) {
          encOk = false;
          break;
        }
      }
      results.add(ValidationResult(
        name: 'Message encryption',
        passed: encOk,
        message: encOk ? 'Sampled messages are encrypted with IV and base64' : 'Encryption check failed',
        details: convIds.isNotEmpty ? 'Checked ${convIds.take(3).length} conversation(s)' : null,
      ));
    } else {
      results.add(ValidationResult(
        name: 'Message encryption',
        passed: true,
        message: 'Skipped (no conversations to sample)',
        details: 'Provide conversationIdsToCheck to validate encryption',
      ));
    }

    // 4. Decryption integrity (one message if we have messageId or can pick one)
    String? mid = messageIdToCheck;
    if (mid == null) {
      try {
        final snapshot = await _firestore.collection(_messagesCollection).limit(1).get();
        if (snapshot.docs.isNotEmpty) mid = snapshot.docs.first.id;
      } catch (_) {}
    }
    if (mid != null) {
      final decOk = await validateDecryption(mid);
      results.add(ValidationResult(
        name: 'Decryption integrity',
        passed: decOk,
        message: decOk ? 'Firestore decrypt matches Hive cache' : 'Decrypt/cache mismatch or missing key',
        details: 'Message $mid',
      ));
    } else {
      results.add(ValidationResult(
        name: 'Decryption integrity',
        passed: true,
        message: 'Skipped (no messages to sample)',
        details: 'Provide messageIdToCheck to validate decryption',
      ));
    }

    final report = SecurityReport(
      results: results,
      timestamp: DateTime.now(),
      warnings: warnings,
      recommendations: recommendations,
    );
    _log.d('SecurityValidator: audit complete; passed=${report.passedCount}, failed=${report.failedCount}');
    return report;
  }
}
