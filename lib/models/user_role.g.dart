// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_role.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserRoleAdapter extends TypeAdapter<UserRole> {
  @override
  final int typeId = 3;

  @override
  UserRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserRole.primary_admin;
      case 1:
        return UserRole.secondary_admin;
      case 2:
        return UserRole.student;
      default:
        return UserRole.primary_admin;
    }
  }

  @override
  void write(BinaryWriter writer, UserRole obj) {
    switch (obj) {
      case UserRole.primary_admin:
        writer.writeByte(0);
        break;
      case UserRole.secondary_admin:
        writer.writeByte(1);
        break;
      case UserRole.student:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
