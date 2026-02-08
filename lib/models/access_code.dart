import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an access code.
enum AccessCodeStatus {
  active,
  used,
  expired,
  revoked,
}

extension AccessCodeStatusX on AccessCodeStatus {
  String get value {
    switch (this) {
      case AccessCodeStatus.active:
        return 'active';
      case AccessCodeStatus.used:
        return 'used';
      case AccessCodeStatus.expired:
        return 'expired';
      case AccessCodeStatus.revoked:
        return 'revoked';
    }
  }

  static AccessCodeStatus fromString(String? v) {
    switch (v) {
      case 'used':
        return AccessCodeStatus.used;
      case 'expired':
        return AccessCodeStatus.expired;
      case 'revoked':
        return AccessCodeStatus.revoked;
      default:
        return AccessCodeStatus.active;
    }
  }
}

/// Represents an access code document in Firestore collection 'access_codes'.
/// Optionally scoped to an [organizationId] for multi-tenant rules.
class AccessCode {
  const AccessCode({
    required this.id,
    required this.code,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.singleUse,
    this.usedAt,
    this.revokedAt,
    this.createdByAdminId,
    this.usedByUserId,
    this.organizationId,
    this.conversationId,
  });

  final String id;
  final String code;
  final AccessCodeStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool singleUse;
  final DateTime? usedAt;
  final DateTime? revokedAt;
  final String? createdByAdminId;
  final String? usedByUserId;

  /// Optional. When set, security rules can restrict access by organization.
  final String? organizationId;

  /// Conversation ID for E2E key exchange; set when code is created with [AccessCodeService].
  final String? conversationId;

  bool get isActive => status == AccessCodeStatus.active;
  bool get used => usedAt != null;
  bool get isExpired =>
      status == AccessCodeStatus.expired ||
      (status == AccessCodeStatus.active && DateTime.now().isAfter(expiresAt));

  factory AccessCode.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime ts(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.now();
    }

    return AccessCode(
      id: doc.id,
      code: data['code'] as String? ?? '',
      status: AccessCodeStatusX.fromString(data['status'] as String?),
      createdAt: ts(data['createdAt']),
      expiresAt: ts(data['expiresAt']),
      singleUse: data['singleUse'] as bool? ?? false,
      usedAt: data['usedAt'] != null ? ts(data['usedAt']) : null,
      revokedAt: data['revokedAt'] != null ? ts(data['revokedAt']) : null,
      createdByAdminId: data['createdByAdminId'] as String? ?? data['createdBy'] as String?,
      usedByUserId: data['usedByUserId'] as String? ?? data['usedBy'] as String?,
      organizationId: data['organizationId'] as String?,
      conversationId: data['conversationId'] as String?,
    );
  }

  /// Serializes to a map for Firestore (uses [Timestamp] for dates).
  Map<String, dynamic> toFirestore() => toMap();

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'singleUse': singleUse,
      if (usedAt != null) 'usedAt': Timestamp.fromDate(usedAt!),
      if (revokedAt != null) 'revokedAt': Timestamp.fromDate(revokedAt!),
      if (createdByAdminId != null) 'createdByAdminId': createdByAdminId,
      if (usedByUserId != null) 'usedByUserId': usedByUserId,
      if (organizationId != null) 'organizationId': organizationId,
      if (conversationId != null) 'conversationId': conversationId,
    };
  }
}

/// Returned by [AccessCodeService.generateAccessCode]: code, QR payload, expiry.
/// Use [qrCodeData] for QR display so students can scan to pre-fill the code.
class AccessCodeData {
  const AccessCodeData({
    required this.code,
    required this.conversationId,
    required this.expiresAt,
    required this.singleUse,
    this.qrCodeData,
  });

  /// The 6-character code (e.g. "ABC123").
  final String code;
  /// Conversation ID for messaging; store locally for this session.
  final String conversationId;
  /// When the code expires.
  final DateTime expiresAt;
  /// Whether the code is single-use.
  final bool singleUse;
  /// Optional payload for QR code (e.g. JSON or plain code) for students to scan.
  final String? qrCodeData;
}
