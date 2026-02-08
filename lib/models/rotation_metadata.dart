import 'dart:convert';

/// Per-conversation metadata for key rotation (last rotation time, message count).
class RotationMetadata {
  final String conversationId;
  final DateTime lastRotatedAt;
  final int messageCountAtRotation;

  const RotationMetadata({
    required this.conversationId,
    required this.lastRotatedAt,
    required this.messageCountAtRotation,
  });

  Map<String, dynamic> toJson() => {
        'conversationId': conversationId,
        'lastRotatedAt': lastRotatedAt.toIso8601String(),
        'messageCountAtRotation': messageCountAtRotation,
      };

  factory RotationMetadata.fromJson(Map<String, dynamic> json) {
    return RotationMetadata(
      conversationId: json['conversationId'] as String,
      lastRotatedAt: DateTime.parse(json['lastRotatedAt'] as String),
      messageCountAtRotation: json['messageCountAtRotation'] as int,
    );
  }

  String toStorageString() => jsonEncode(toJson());

  static RotationMetadata? fromStorageString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return RotationMetadata.fromJson(
          jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
