import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/access_code.dart';
import '../models/conversation_data.dart';
import 'encryption_service.dart';
import 'key_manager.dart';
import 'local_storage_service.dart';
import 'message_storage_interface.dart';

/// Thrown when access code generation, redemption, or key recovery fails.
class AccessCodeServiceException implements Exception {
  const AccessCodeServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AccessCodeServiceException: $message${cause != null ? ' | cause: $cause' : ''}';
}

/// Character set for 6-char codes: alphanumeric excluding ambiguous 0, O, I, 1, l.
const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Max access codes an admin can generate per day (rate limit).
const int _maxCodesPerDayPerAdmin = 100;

/// Max redemption attempts per minute (client-side throttle to reduce brute force).
const int _maxRedemptionAttemptsPerMinute = 10;

/// Default expiry for codes when [expiryDays] not provided (max 30 days).
const int _defaultExpiryDays = 30;
const int _maxExpiryDays = 30;

/// Access code generation and key exchange: admin creates code + conversation key,
/// student redeems code and receives the same key for E2E encryption.
///
/// Crypto flow:
/// - **Generate:** Create 6-char code, new AES-256 conversation key, new conversation ID.
///   Encrypt conversation key with (1) org master key → store as [encryptedConversationKey] (admin recovery),
///   (2) key derived from code (PBKDF2) → store as [encryptedForStudent] (student redeem).
///   Store conversation key in admin's local Hive. Write doc to Firestore.
/// - **Redeem:** Find doc by code, validate not expired/used, decrypt [encryptedForStudent] with
///   key derived from code, store conversation key in student's Hive, mark code used.
/// - **Recover:** (Admin on new device.) Fetch codes created by admin, decrypt [encryptedConversationKey]
///   with org master key, store each conversation key in Hive.
class AccessCodeService {
  AccessCodeService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    KeyManagerStorage? organizationKeyStorage,
    EncryptionService? encryptionService,
    MessageServiceStorage? storage,
    KeyManager? keyManager,
    Logger? logger,
    /// Optional: validate that [adminUserId] is allowed to act for [organizationId].
    Future<bool> Function(String organizationId, String adminUserId)? validateOrganizationPermission,
  })  : _firestore = firestore,
        _auth = auth,
        _orgKeyStorage = organizationKeyStorage ?? SecureStorageAdapter(),
        _encryption = encryptionService ?? EncryptionService(),
        _storage = storage ?? LocalStorageService.instance,
        _keyManager = keyManager ?? KeyManager(),
        _log = logger ?? Logger(),
        _validateOrgPermission = validateOrganizationPermission;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final KeyManagerStorage _orgKeyStorage;
  final EncryptionService _encryption;
  final MessageServiceStorage _storage;
  final KeyManager _keyManager;
  final Logger _log;
  final Future<bool> Function(String organizationId, String adminUserId)? _validateOrgPermission;

  static const String _accessCodesCollection = 'access_codes';
  static const String _orgMasterKeyPrefix = 'anon_cast_org_master_';

  final List<DateTime> _redemptionAttempts = [];

  /// Generates a 6-character code from [_codeChars] (excludes ambiguous 0,O,I,1,l).
  String _generateCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _codeChars[r.nextInt(_codeChars.length)]).join();
  }

  /// Returns org master key if present; null if not set (e.g. new device).
  Future<String?> _getOrganizationMasterKey(String organizationId) async {
    final key = '$_orgMasterKeyPrefix$organizationId';
    return _orgKeyStorage.read(key: key);
  }

  /// Gets or creates the org master key (for generation only). On new device, create = first use.
  Future<String> _getOrCreateOrganizationMasterKey(String organizationId) async {
    final value = await _getOrganizationMasterKey(organizationId);
    if (value != null && value.isNotEmpty) return value;
    final newKey = _keyManager.generateKey();
    final encoded = base64Encode(newKey);
    await _orgKeyStorage.write(key: '$_orgMasterKeyPrefix$organizationId', value: encoded);
    _log.d('AccessCodeService: created new org master key for $organizationId');
    return encoded;
  }

  /// Rate limit: max [_maxCodesPerDayPerAdmin] codes per admin per day.
  Future<void> _checkGenerationRateLimit(String adminUserId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snapshot = await _firestore
        .collection(_accessCodesCollection)
        .where('createdBy', isEqualTo: adminUserId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    if (snapshot.docs.length >= _maxCodesPerDayPerAdmin) {
      throw AccessCodeServiceException(
        'Rate limit: max $_maxCodesPerDayPerAdmin access codes per day.',
      );
    }
  }

  /// Throttle redemption attempts (client-side) to reduce brute force.
  /// Client-side throttle: max [_maxRedemptionAttemptsPerMinute] attempts per minute.
  void _checkRedemptionThrottle() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 1));
    _redemptionAttempts.removeWhere((t) => t.isBefore(cutoff));
    if (_redemptionAttempts.length >= _maxRedemptionAttemptsPerMinute) {
      throw AccessCodeServiceException(
        'Too many redemption attempts. Please wait a minute.',
      );
    }
    _redemptionAttempts.add(now);
  }

  /// Admin: generates access code + conversation key, stores encrypted key in Firestore and locally.
  ///
  /// Steps: (a) 6-char code, (b) new AES-256 conversation key, (c) new conversation ID,
  /// (d) encrypt key with org master key, (e) store in Firestore, (f) store key in admin Hive, (g) return [AccessCodeData].
  Future<AccessCodeData> generateAccessCode({
    required String organizationId,
    required String adminUserId,
    int? expiryDays,
    bool singleUse = true,
  }) async {
    if (organizationId.isEmpty || adminUserId.isEmpty) {
      throw AccessCodeServiceException('organizationId and adminUserId are required.');
    }
    if (_validateOrgPermission != null && !await _validateOrgPermission!(organizationId, adminUserId)) {
      _log.w('AccessCodeService: permission denied for org $organizationId user $adminUserId');
      throw AccessCodeServiceException('Permission denied for this organization.');
    }

    await _checkGenerationRateLimit(adminUserId);

    final days = expiryDays != null
        ? expiryDays.clamp(1, _maxExpiryDays)
        : _defaultExpiryDays;
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: days));

    String code;
    int attempts = 0;
    do {
      code = _generateCode();
      final existing = await _firestore
          .collection(_accessCodesCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) break;
      if (++attempts > 20) throw AccessCodeServiceException('Could not generate unique code.');
    } while (true);

    final conversationId = 'conv_${const Uuid().v4().replaceAll('-', '')}';
    final conversationKeyBase64 = base64Encode(_keyManager.generateKey());

    final orgMasterKey = await _getOrCreateOrganizationMasterKey(organizationId);
    final encryptedForAdmin = await _encryption.encryptMessage(conversationKeyBase64, orgMasterKey);

    final derivedKey = await _encryption.deriveKeyFromCode(code, conversationId);
    final encryptedForStudent = await _encryption.encryptMessage(conversationKeyBase64, derivedKey);

    final doc = {
      'code': code,
      'conversationId': conversationId,
      'encryptedConversationKey': {
        'content': encryptedForAdmin.encryptedContent,
        'iv': encryptedForAdmin.iv,
      },
      'encryptedForStudent': {
        'content': encryptedForStudent.encryptedContent,
        'iv': encryptedForStudent.iv,
      },
      'organizationId': organizationId,
      'createdBy': adminUserId,
      'createdByAdminId': adminUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'singleUse': singleUse,
      'used': false,
      'usedAt': null,
      'usedBy': null,
      'usedByUserId': null,
      'status': 'active',
    };

    final ref = _firestore.collection(_accessCodesCollection).doc();
    await ref.set(doc);

    await _encryption.storeKeyLocally(conversationId, conversationKeyBase64);
    await _storage.storeConversationKey(conversationId, conversationKeyBase64);

    _log.i('AccessCodeService: generated code ${ref.id} for org $organizationId by $adminUserId');
    return AccessCodeData(
      code: code,
      conversationId: conversationId,
      expiresAt: expiresAt,
      singleUse: singleUse,
      qrCodeData: code,
    );
  }

  /// Student: redeems code, receives conversation key, stores in Hive, returns [ConversationData].
  ///
  /// Steps: (a) query Firestore by code, (b) validate not expired/used, (c) mark used,
  /// (d) decrypt [encryptedForStudent] with key derived from code, (e) store key in Hive,
  /// (f) caller creates anonymous session; (g) return conversation id and info.
  Future<ConversationData> redeemAccessCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw AccessCodeServiceException('Access code is required.');
    }

    _checkRedemptionThrottle();

    final snapshot = await _firestore
        .collection(_accessCodesCollection)
        .where('code', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      _log.w('AccessCodeService: redeem failed - code not found');
      throw AccessCodeServiceException('Invalid or expired code.');
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    final status = data['status'] as String? ?? 'active';
    if (status != 'active') {
      if (status == 'used') throw AccessCodeServiceException('This code has already been used.');
      if (status == 'revoked') throw AccessCodeServiceException('This code has been revoked.');
      throw AccessCodeServiceException('Invalid or expired code.');
    }

    final expiresAtRaw = data['expiresAt'];
    DateTime? expiresAt;
    if (expiresAtRaw is Timestamp) expiresAt = expiresAtRaw.toDate();
    if (expiresAtRaw is int) expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtRaw);
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw AccessCodeServiceException('This code has expired.');
    }

    final conversationId = data['conversationId'] as String? ?? '';
    final organizationId = data['organizationId'] as String? ?? '';
    final createdBy = data['createdBy'] as String? ?? '';

    if (conversationId.isEmpty) {
      throw AccessCodeServiceException('Invalid code document (missing conversation).');
    }

    final encryptedForStudent = data['encryptedForStudent'] as Map<String, dynamic>?;
    if (encryptedForStudent == null) {
      throw AccessCodeServiceException('Invalid code document (missing key data).');
    }
    final content = encryptedForStudent['content'] as String? ?? '';
    final iv = encryptedForStudent['iv'] as String? ?? '';
    if (content.isEmpty || iv.isEmpty) {
      throw AccessCodeServiceException('Invalid code document (corrupted key data).');
    }

    String conversationKeyBase64;
    try {
      final derivedKey = await _encryption.deriveKeyFromCode(normalized, conversationId);
      conversationKeyBase64 = await _encryption.decryptMessage(content, iv, derivedKey);
    } on EncryptionServiceException catch (e) {
      _log.w('AccessCodeService: redeem decrypt failed', error: e);
      throw AccessCodeServiceException('Invalid or expired code.');
    }

    await _encryption.storeKeyLocally(conversationId, conversationKeyBase64);
    await _storage.storeConversationKey(conversationId, conversationKeyBase64);

    final usedBy = _auth.currentUser?.uid;
    await doc.reference.update({
      'status': 'used',
      'used': true,
      'usedAt': FieldValue.serverTimestamp(),
      'usedBy': usedBy,
      'usedByUserId': usedBy,
    });

    _log.i('AccessCodeService: redeemed code ${doc.id} by ${usedBy ?? 'anonymous'}');
    return ConversationData(
      conversationId: conversationId,
      organizationId: organizationId,
      adminUserId: createdBy.isNotEmpty ? createdBy : null,
      expiresAt: expiresAt,
    );
  }

  /// Admin recovery: decrypt all conversation keys for codes created by [adminUserId] and store in Hive.
  ///
  /// Use when admin logs in on a new device to restore access to existing conversations.
  Future<void> recoverConversationKeys(String adminUserId) async {
    if (adminUserId.isEmpty) {
      throw AccessCodeServiceException('adminUserId is required.');
    }

    final snapshot = await _firestore
        .collection(_accessCodesCollection)
        .where('createdBy', isEqualTo: adminUserId)
        .get();

    int recovered = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final conversationId = data['conversationId'] as String?;
      final organizationId = data['organizationId'] as String?;
      if (conversationId == null || conversationId.isEmpty || organizationId == null) continue;

      final enc = data['encryptedConversationKey'] as Map<String, dynamic>?;
      if (enc == null) continue;
      final content = enc['content'] as String? ?? '';
      final iv = enc['iv'] as String? ?? '';
      if (content.isEmpty || iv.isEmpty) continue;

      final orgMasterKey = await _getOrganizationMasterKey(organizationId);
      if (orgMasterKey == null || orgMasterKey.isEmpty) {
        _log.w('AccessCodeService: no org master key for $organizationId, skip recovery for ${doc.id}');
        continue;
      }
      try {
        final keyBase64 = await _encryption.decryptMessage(content, iv, orgMasterKey);
        await _encryption.storeKeyLocally(conversationId, keyBase64);
        await _storage.storeConversationKey(conversationId, keyBase64);
        recovered++;
      } on EncryptionServiceException catch (e) {
        _log.w('AccessCodeService: recover decrypt failed for ${doc.id}', error: e);
      }
    }

    _log.i('AccessCodeService: recovered $recovered conversation keys for $adminUserId');
  }
}
