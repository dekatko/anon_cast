import 'package:anon_cast/models/chat_message.dart';

class ChatSession {
  final String username; // Username of the anonymous user (optional)
  final List<ChatMessage> messages; // List of messages in the current chat sesh
  final DateTime startedAt; // Timestamp of the chat session start

  ChatSession(this.username, this.messages, this.startedAt);
}
