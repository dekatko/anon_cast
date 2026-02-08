import 'package:cloud_firestore/cloud_firestore.dart';

/// Message thread between an anonymous user and an admin in collection `conversations`.
/// Contains metadata and optional typing state; messages live in subcollection or `messages` with conversationId.
class Conversation {
  const Conversation({
    required this.id,
    required this.organizationId,
    required this.adminId,
    required this.anonymousUserId,
    required this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.typingAdmin,
    this.typingAnonymous,
  });

  final String id;
  final String organizationId;
  final String adminId;
  final String anonymousUserId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final bool? typingAdmin;
  final bool? typingAnonymous;

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
    final adminId = data['adminId'] as String? ?? '';
    final anonymousUserId = data['anonymousUserId'] as String? ?? '';
    return Conversation(
      id: id,
      organizationId: orgId,
      adminId: adminId,
      anonymousUserId: anonymousUserId,
      createdAt: _parseTimestamp(data['createdAt'], id, 'createdAt'),
      updatedAt: _parseTimestampOrNull(data['updatedAt']),
      lastMessageAt: _parseTimestampOrNull(data['lastMessageAt']),
      typingAdmin: data['typingAdmin'] as bool?,
      typingAnonymous: data['typingAnonymous'] as bool?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'adminId': adminId,
      'anonymousUserId': anonymousUserId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (lastMessageAt != null) 'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      if (typingAdmin != null) 'typingAdmin': typingAdmin,
      if (typingAnonymous != null) 'typingAnonymous': typingAnonymous,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'adminId': adminId,
      'anonymousUserId': anonymousUserId,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt!.toIso8601String(),
      if (typingAdmin != null) 'typingAdmin': typingAdmin,
      if (typingAnonymous != null) 'typingAnonymous': typingAnonymous,
    };
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
