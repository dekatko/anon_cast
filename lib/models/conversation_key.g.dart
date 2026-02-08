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
    return ConversationKey(
      id: fields[0] as String,
      key: fields[1] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      lastRotated: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
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
