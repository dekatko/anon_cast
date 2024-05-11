import 'package:hive/hive.dart';

part 'chat_room.g.dart';

@HiveType(typeId: 5)
class ChatRoom {
  @HiveField(0)
  final String id; // Unique identifier for the chat room
  @HiveField(1)
  final String topic;
  @HiveField(2)
  final String? description;

  ChatRoom({
    required this.id,
    required this.topic,
    this.description,
  });
}