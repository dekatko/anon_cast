import 'package:anon_cast/models/chat_message.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

final log = Logger();

class ChatSession {
  final String id;
  final String name;
  final String studentId; // Username of the anonymous user (optional)
  final String adminId;
  final DateTime startedAt; // Timestamp of the chat session start
  final DateTime lastActive;
  final List<ChatMessage> messages; // List of messages in the current chat sesh

  ChatSession({
    required this.id,
    required this.name,
    required this.studentId,
    required this.adminId,
    required this.startedAt,
    required this.lastActive,
    required this.messages,
  });

  factory ChatSession.create() {
    const uuid = Uuid();
    return ChatSession(
      id: uuid.v4(),
      name: '',
      studentId: '',
      adminId: '',
      startedAt: DateTime.now(),
      messages: [],
      lastActive: DateTime.now(),
    );
  }


  factory ChatSession.fromMap(Map<dynamic, dynamic> map) {
    log.i("");
    return ChatSession(
      id: map['id'] as String,
      name: map['name'] as String,
      studentId: map['questionerId'] as String,
      adminId: map['adminId'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      lastActive: DateTime.fromMillisecondsSinceEpoch(map['lastActive'] as int),
      messages: (map['messages'] as List<dynamic>).map((messageData) => ChatMessage.fromMap(messageData)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionerId': studentId,
      'adminId': adminId,
      'startedAt': startedAt.millisecondsSinceEpoch, // Convert DateTime to milliseconds
      'lastActive': lastActive.millisecondsSinceEpoch,
      'messages': messages.map((message) => message.toMap()).toList(), // Convert messages to maps
    };
  }
}
