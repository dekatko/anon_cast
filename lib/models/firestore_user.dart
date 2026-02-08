import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin/counselor account in Firestore collection `users`.
/// Scoped to an [organizationId]. Used for auth and access control.
class FirestoreUser {
  const FirestoreUser({
    required this.id,
    required this.email,
    required this.organizationId,
    required this.createdAt,
    this.displayName,
    this.role,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String organizationId;
  final DateTime createdAt;
  final String? displayName;
  /// e.g. 'admin', 'counselor', 'primary_admin', 'secondary_admin'
  final String? role;
  final DateTime? updatedAt;

  bool get isAdmin => true;

  /// Creates a [FirestoreUser] from a Firestore document.
  factory FirestoreUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError('User document ${doc.id} has no data');
    }
    final id = doc.id;
    final email = data['email'] as String?;
    if (email == null || email.isEmpty) {
      throw ArgumentError('User $id missing or empty email');
    }
    final orgId = data['organizationId'] as String?;
    if (orgId == null || orgId.isEmpty) {
      throw ArgumentError('User $id missing or empty organizationId');
    }
    return FirestoreUser(
      id: id,
      email: email,
      organizationId: orgId,
      displayName: data['displayName'] as String?,
      role: data['role'] as String?,
      createdAt: _parseTimestamp(data['createdAt'], id, 'createdAt'),
      updatedAt: _parseTimestampOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'organizationId': organizationId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (displayName != null) 'displayName': displayName,
      if (role != null) 'role': role,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'organizationId': organizationId,
      'createdAt': createdAt.toIso8601String(),
      if (displayName != null) 'displayName': displayName,
      if (role != null) 'role': role,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  static DateTime _parseTimestamp(dynamic v, String docId, String field) {
    if (v == null) throw ArgumentError('User $docId missing $field');
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    throw ArgumentError('User $docId invalid $field type');
  }

  static DateTime? _parseTimestampOrNull(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
