import 'package:hive/hive.dart';

/// Per-conversation encryption key for zero-knowledge E2E.
///
/// Stored **only in Hive** on device; never sent to Firestore.
/// [key] is the AES key, base64-encoded for storage.
class ConversationKey {
  const ConversationKey({
    required this.id,
    required this.key,
    required this.createdAt,
    DateTime? lastRotated,
  }) : lastRotated = lastRotated ?? createdAt;

  /// Conversation id this key belongs to.
  final String id;
  /// Base64-encoded AES key (never leave the device).
  final String key;
  /// When this key was created.
  final DateTime createdAt;
  /// When the key was last rotated (defaults to [createdAt]).
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

/// Hive TypeAdapter for [ConversationKey].
class ConversationKeyAdapter extends TypeAdapter<ConversationKey> {
  @override
  final int typeId = 7;

  @override
  ConversationKey read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final created = fields[2] as int? ?? 0;
    final rotated = fields[3] as int? ?? created;
    return ConversationKey(
      id: fields[0] as String? ?? '',
      key: fields[1] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(created),
      lastRotated: DateTime.fromMillisecondsSinceEpoch(rotated),
    );
  }

  @override
  void write(BinaryWriter writer, ConversationKey obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.key)
      ..writeByte(2)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.lastRotated.millisecondsSinceEpoch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationKeyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
