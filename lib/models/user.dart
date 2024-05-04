import 'package:anon_cast/models/user_role.dart';
import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final UserRole role; //"primary_admin", "secondary_admin", or "student"

  User({
    required this.id,
    required this.name,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) =>
      User(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as UserRole,
      );

  // Additional methods can be added here, like converting to a JSON map
  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'name': name,
        'role': role,
      };

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      name: map['name'] as String,
      role: map['role'] as UserRole,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
    };
  }
}
