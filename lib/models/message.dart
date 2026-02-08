import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a message (for admin workflow).
enum MessageStatus {
  unread,
  read,
  resolved,
}

extension MessageStatusX on MessageStatus {
  String get value {
    switch (this) {
      case MessageStatus.unread:
        return 'unread';
      case MessageStatus.read:
        return 'read';
      case MessageStatus.resolved:
        return 'resolved';
    }
  }

  static MessageStatus fromString(String? v) {
    switch (v) {
      case 'read':
        return MessageStatus.read;
      case 'resolved':
        return MessageStatus.resolved;
      default:
        return MessageStatus.unread;
    }
  }
}

/// A single message in Firestore collection `messages`.
/// Links to a conversation via [conversationId]. Supports encryption (iv) and status.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.encryptedContent,
    required this.timestamp,
    required this.status,
    this.iv,
    this.preview,
    this.senderType,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String encryptedContent;
  final DateTime timestamp;
  final MessageStatus status;
  final List<int>? iv;
  final String? preview;
  final String? senderType;

  bool get isUnread => status == MessageStatus.unread;

  /// Creates a [Message] from a Firestore document.
  factory Message.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError('Message document ${doc.id} has no data');
    }
    final id = doc.id;
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null || conversationId.isEmpty) {
      throw ArgumentError('Message $id missing conversationId');
    }
    final senderId = data['senderId'] as String? ?? '';
    final encryptedContent = data['encryptedContent'] as String? ?? '';
    final timestamp = _parseTimestamp(data['timestamp'], id, 'timestamp');
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      encryptedContent: encryptedContent,
      timestamp: timestamp,
      status: MessageStatusX.fromString(data['status'] as String?),
      iv: (data['iv'] as List<dynamic>?)?.cast<int>(),
      preview: data['preview'] as String?,
      senderType: data['senderType'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'encryptedContent': encryptedContent,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.value,
      if (iv != null && iv!.isNotEmpty) 'iv': iv,
      if (preview != null) 'preview': preview,
      if (senderType != null) 'senderType': senderType,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'encryptedContent': encryptedContent,
      'timestamp': timestamp.toIso8601String(),
      'status': status.value,
      if (iv != null) 'iv': iv,
      if (preview != null) 'preview': preview,
      if (senderType != null) 'senderType': senderType,
    };
  }

  static DateTime _parseTimestamp(dynamic v, String docId, String field) {
    if (v == null) throw ArgumentError('Message $docId missing $field');
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    throw ArgumentError('Message $docId invalid $field type');
  }
}
