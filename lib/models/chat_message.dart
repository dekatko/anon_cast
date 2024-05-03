import 'dart:typed_data';

import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 1)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id; // Unique identifier for the message
  @HiveField(1)
  final String senderId; // ID of the user who sent the message
  @HiveField(2)
  final String encryptedContent; // Encrypted message content (base64 encoded)
  @HiveField(3)
  final String timestamp; // Time the message was sent
  @HiveField(4)
  final Uint8List? iv; // Optional: Initialization Vector (if used)

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.encryptedContent,
    required this.timestamp,
    this.iv,
  });

  Future<void> saveMessage(ChatMessage message) async {
    final box = await Hive.openBox('chat_messages');
    box.add(message);
  }

  Future<List<ChatMessage>> getMessages() async {
    final box = await Hive.openBox('chat_messages');
    return box.values.toList().cast<ChatMessage>(); // Cast to your Message type
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      encryptedContent: json['encryptedContent'] as String,
      timestamp: json['timestamp'] as String,
      iv: json['iv']?.cast<int>(), // Convert 'iv' to Uint8List if it exists
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'encryptedContent': encryptedContent,
        'timestamp': timestamp,
        'iv': iv?.toList(), // Convert optional iv to a list if it exists
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      encryptedContent: map['encryptedContent'] as String,
      timestamp: map['timestamp'] as String,
      iv: map['iv']?.cast<int>(), // Handle optional iv
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'encryptedContent': encryptedContent,
      'timestamp': timestamp,
      'iv': iv?.toList(), // Convert optional iv to a list if it exists
    };
  }
}
