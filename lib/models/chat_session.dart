import 'package:anon_cast/models/chat_message.dart';

class ChatSession {
  final String username; // Username of the anonymous user (optional)
  final DateTime startedAt; // Timestamp of the chat session start
  final List<ChatMessage> messages; // List of messages in the current chat sesh

  ChatSession({required this.username, required this.startedAt, required this.messages});

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      username: map['username'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      messages: (map['messages'] as List<dynamic>).map((messageData) => ChatMessage.fromMap(messageData)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'startedAt': startedAt.millisecondsSinceEpoch, // Convert DateTime to milliseconds
      'messages': messages.map((message) => message.toMap()).toList(), // Convert messages to maps
    };
  }
}
