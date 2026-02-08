import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a school or institution in Firestore collection `organizations`.
/// Admins and access codes are scoped to an organization.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.createdAt,
    this.updatedAt,
    this.settings,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? settings;

  /// Creates an [Organization] from a Firestore document.
  /// Validates required fields and normalizes types.
  factory Organization.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError('Organization document ${doc.id} has no data');
    }
    final id = doc.id;
    final name = data['name'] as String?;
    if (name == null || name.isEmpty) {
      throw ArgumentError('Organization $id missing or empty name');
    }
    return Organization(
      id: id,
      name: name,
      createdAt: _parseTimestamp(data['createdAt'], id, 'createdAt'),
      updatedAt: _parseTimestampOrNull(data['updatedAt']),
      settings: data['settings'] as Map<String, dynamic>?,
    );
  }

  /// Serializes to a map suitable for Firestore (uses [Timestamp] for dates).
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (settings != null && settings!.isNotEmpty) 'settings': settings,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (settings != null) 'settings': settings,
    };
  }

  static DateTime _parseTimestamp(dynamic v, String docId, String field) {
    if (v == null) throw ArgumentError('Organization $docId missing $field');
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    throw ArgumentError('Organization $docId invalid $field type');
  }

  static DateTime? _parseTimestampOrNull(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
