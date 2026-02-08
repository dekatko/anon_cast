import 'package:hive/hive.dart';

part 'conversation_key.g.dart';

/// Per-conversation encryption key for zero-knowledge E2E.
///
/// Stored **only in Hive** on device; never sent to Firestore.
/// [key] is the AES key, base64-encoded for storage.
@HiveType(typeId: 7)
class ConversationKey {
  const ConversationKey({
    required this.id,
    required this.key,
    required this.createdAt,
    DateTime? lastRotated,
  }) : lastRotated = lastRotated ?? createdAt;

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String key;
  @HiveField(2)
  final DateTime createdAt;
  @HiveField(3)
  final DateTime lastRotated;

  /// From local/Hive map.
  factory ConversationKey.fromMap(Map<dynamic, dynamic> map) {
    final created = map['createdAt'];
    final rotated = map['lastRotated'];
    DateTime createdAt = DateTime.now();
    if (created != null) {
      if (created is int) createdAt = DateTime.fromMillisecondsSinceEpoch(created);
      if (created is num) createdAt = DateTime.fromMillisecondsSinceEpoch(created.toInt());
    }
    DateTime lastRotated = createdAt;
    if (rotated != null) {
      if (rotated is int) lastRotated = DateTime.fromMillisecondsSinceEpoch(rotated);
      if (rotated is num) lastRotated = DateTime.fromMillisecondsSinceEpoch(rotated.toInt());
    }
    return ConversationKey(
      id: map['id'] as String? ?? '',
      key: map['key'] as String? ?? '',
      createdAt: createdAt,
      lastRotated: lastRotated,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'key': key,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastRotated': lastRotated.millisecondsSinceEpoch,
      };

  ConversationKey copyWith({
    String? id,
    String? key,
    DateTime? createdAt,
    DateTime? lastRotated,
  }) {
    return ConversationKey(
      id: id ?? this.id,
      key: key ?? this.key,
      createdAt: createdAt ?? this.createdAt,
      lastRotated: lastRotated ?? this.lastRotated,
    );
  }
}
