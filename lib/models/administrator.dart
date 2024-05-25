class Administrator {
  final String uid;
  final String adminCode;
  final String email;
  final String? name; // Optional field for administrator name

  Administrator({
    required this.uid,
    required this.adminCode,
    required this.email,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'adminCode': adminCode,
      'name': name,
    };
  }

  factory Administrator.fromMap(Map<String, dynamic> map) {
    return Administrator(
      uid: map['uid'] as String,
      email: map['email'] as String,
      adminCode: map['adminCode'] as String,
      name: map['name'] as String?,
    );
  }
}