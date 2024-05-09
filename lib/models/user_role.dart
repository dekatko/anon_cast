import 'package:hive/hive.dart';

part 'user_role.g.dart';

@HiveType(typeId: 3)
enum UserRole {
  @HiveField(0)
  primary_admin,
  @HiveField(1)
  secondary_admin,
  @HiveField(2)
  student
}