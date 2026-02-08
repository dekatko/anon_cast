import 'package:cloud_firestore/cloud_firestore.dart';

/// Conversation lifecycle status (admin workflow).
enum ConversationStatus {
  active,
  resolved,
  archived,
}

extension ConversationStatusX on ConversationStatus {
  String get value {
    switch (this) {
      case ConversationStatus.active:
        return 'active';
      case ConversationStatus.resolved:
        return 'resolved';
      case ConversationStatus.archived:
        return 'archived';
    }
  }

  static ConversationStatus fromString(String? v) {
    switch (v) {
      case 'resolved':
        return ConversationStatus.resolved;
      case 'archived':
        return ConversationStatus.archived;
      default:
        return ConversationStatus.active;
    }
  }
}

/// Message thread between an anonymous user and an admin in collection `conversations`.
/// Contains metadata only (no encryption keys in Firestore); keys live in Hive.
class Conversation {
  const Conversation({
    required this.id,
    required this.organizationId,
    required this.createdAt,
    this.adminId,
    this.anonymousUserId,
    this.createdBy,
    this.updatedAt,
    this.lastMessageAt,
    this.messageCount = 0,
    this.status = ConversationStatus.active,
    this.typingAdmin,
    this.typingAnonymous,
    this.metadata,
    this.unreadCount,
    this.lastMessagePreview,
  });

  final String id;
  final String organizationId;
  final DateTime createdAt;
  /// Admin who created or owns the conversation (legacy: [adminId]).
  final String? adminId;
  final String? anonymousUserId;
  /// Set when creating via [ConversationService]; preferred over [adminId] for new docs.
  final String? createdBy;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final int messageCount;
  final ConversationStatus status;
  final bool? typingAdmin;
  final bool? typingAnonymous;
  /// Optional extra fields (not sent to Firestore as-is; flatten if needed).
  final Map<String, dynamic>? metadata;
  /// Set when enriching from Hive (not stored in Firestore).
  final int? unreadCount;
  /// Latest message preview from Hive (not stored in Firestore).
  final String? lastMessagePreview;

  /// Creates a [Conversation] from a Firestore document.
  factory Conversation.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError('Conversation document ${doc.id} has no data');
    }
    final id = doc.id;
    final orgId = data['organizationId'] as String?;
    if (orgId == null || orgId.isEmpty) {
      throw ArgumentError('Conversation $id missing organizationId');
    }
    final createdBy = data['createdBy'] as String?;
    final adminId = data['adminId'] as String? ?? createdBy ?? '';
    final anonymousUserId = data['anonymousUserId'] as String? ?? '';
    final messageCount = data['messageCount'] as int? ?? 0;
    final status = ConversationStatusX.fromString(data['status'] as String?);
    return Conversation(
      id: id,
      organizationId: orgId,
      adminId: adminId,
      anonymousUserId: anonymousUserId.isEmpty ? null : anonymousUserId,
      createdBy: createdBy,
      createdAt: _parseTimestamp(data['createdAt'], id, 'createdAt'),
      updatedAt: _parseTimestampOrNull(data['updatedAt']),
      lastMessageAt: _parseTimestampOrNull(data['lastMessageAt']),
      messageCount: messageCount,
      status: status,
      typingAdmin: data['typingAdmin'] as bool?,
      typingAnonymous: data['typingAnonymous'] as bool?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Serializes to Firestore (metadata only; no sensitive data). Omits [unreadCount] and [lastMessagePreview].
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'organizationId': organizationId,
      'createdBy': createdBy ?? adminId ?? '',
      if (adminId != null && adminId!.isNotEmpty) 'adminId': adminId,
      if (anonymousUserId != null && anonymousUserId!.isNotEmpty) 'anonymousUserId': anonymousUserId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (lastMessageAt != null) 'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      'messageCount': messageCount,
      'status': status.value,
      if (typingAdmin != null) 'typingAdmin': typingAdmin,
      if (typingAnonymous != null) 'typingAnonymous': typingAnonymous,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'adminId': adminId,
      'anonymousUserId': anonymousUserId,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt!.toIso8601String(),
      'messageCount': messageCount,
      'status': status.value,
      if (typingAdmin != null) 'typingAdmin': typingAdmin,
      if (typingAnonymous != null) 'typingAnonymous': typingAnonymous,
    };
  }

  Conversation copyWith({
    String? id,
    String? organizationId,
    String? adminId,
    String? anonymousUserId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    int? messageCount,
    ConversationStatus? status,
    bool? typingAdmin,
    bool? typingAnonymous,
    Map<String, dynamic>? metadata,
    int? unreadCount,
    String? lastMessagePreview,
  }) {
    return Conversation(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      adminId: adminId ?? this.adminId,
      anonymousUserId: anonymousUserId ?? this.anonymousUserId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messageCount: messageCount ?? this.messageCount,
      status: status ?? this.status,
      typingAdmin: typingAdmin ?? this.typingAdmin,
      typingAnonymous: typingAnonymous ?? this.typingAnonymous,
      metadata: metadata ?? this.metadata,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }

  static DateTime _parseTimestamp(dynamic v, String docId, String field) {
    if (v == null) throw ArgumentError('Conversation $docId missing $field');
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    throw ArgumentError('Conversation $docId invalid $field type');
  }

  static DateTime? _parseTimestampOrNull(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

/// Local metadata for a conversation (from Hive + key storage).
/// Used by [ConversationService.getMetadata].
class ConversationMetadata {
  const ConversationMetadata({
    required this.messageCount,
    required this.unreadCount,
    this.lastMessageAt,
    this.hasEncryptionKey = false,
  });

  final int messageCount;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final bool hasEncryptionKey;
}
