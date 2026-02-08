// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_key.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConversationKeyAdapter extends TypeAdapter<ConversationKey> {
  @override
  final int typeId = 7;

  @override
  ConversationKey read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final version = numOfFields >= 5 && fields[4] != null ? fields[4] as int : 1;
    final oldKeysJson = numOfFields >= 6 && fields[5] != null ? fields[5] as String : '[]';
    return ConversationKey._withOldKeysJson(
      id: fields[0] as String,
      key: fields[1] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      lastRotated: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      version: version,
      oldKeysJson: oldKeysJson,
    );
  }

  @override
  void write(BinaryWriter writer, ConversationKey obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.key)
      ..writeByte(2)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.lastRotated.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.version)
      ..writeByte(5)
      ..write(obj.oldKeysJson);
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
