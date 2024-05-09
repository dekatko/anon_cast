import 'dart:convert';
import 'dart:typed_data';

import 'package:anon_cast/models/user_role.dart';
import 'package:hive/hive.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

part 'user.g.dart';

@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final UserRole role; //"primary_admin", "secondary_admin", or "student"

  final String _password;

  User({
    required this.id,
    required this.name,
    required this.role,
    required String password,
  }) : _password = password; // Store password temporarily

  String get password => _password;

  factory User.fromJson(Map<String, dynamic> json) =>
      User(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as UserRole,
        password: '',
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
      password: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
    };
  }

  String hashPassword(String password) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = SecureRandom().nextBytes(32);

    final params = Pbkdf2Parameters(saltBytes, 10000, 256);
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(params);
    final hashBytes = pbkdf2.process(Uint8List.fromList(passwordBytes));
    return base64.encode(hashBytes);
  }
}
