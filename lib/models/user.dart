import 'package:anon_cast/models/user_role.dart';

class User {
  final String id;
  final String name;
  final UserRole
      role; // Can be "primary_admin", "secondary_admin", or "student"

  User({
    required this.id,
    required this.name,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as UserRole,
      );

  // Additional methods can be added here, like converting to a JSON map
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
      };
}
