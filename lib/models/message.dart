import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

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

/// A single message in the zero-knowledge E2E architecture.
///
/// - **Firestore** stores only [encryptedContent] and [iv] (we cannot read plaintext on server).
/// - **Hive** (local) stores decrypted [content] for fast access; keys never leave the device.
///
/// Use [toFirestore] when sending to Firestore (encrypted data only).
/// Use [fromFirestore] when receiving from Firestore (encrypted); decrypt locally and set [content].
/// Use [MessageAdapter] for Hive local storage (plaintext [content]).
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.encryptedContent,
    required this.timestamp,
    required this.status,
    this.content,
    this.iv,
    this.preview,
    this.senderType,
  });

  /// Server document id or local id.
  final String id;
  /// Conversation this message belongs to.
  final String conversationId;
  /// Sender user id.
  final String senderId;
  /// Encrypted payload for Firestore (base64 or hex); never store plaintext on server.
  final String encryptedContent;
  /// Decrypted plaintext for local (Hive) only; never sent to Firestore.
  final String? content;
  /// Initialization vector for decryption; required to decrypt [encryptedContent].
  final List<int>? iv;
  /// Message timestamp.
  final DateTime timestamp;
  /// Admin workflow status (unread / read / resolved).
  final MessageStatus status;
  /// Optional short preview (e.g. first N chars); may be encrypted or placeholder.
  final String? preview;
  /// 'admin' or 'anonymous'.
  final String? senderType;

  /// True when [encryptedContent] is non-empty and decryption is needed to obtain plaintext
  /// (i.e. [content] is null or empty).
  bool get isEncrypted =>
      encryptedContent.isNotEmpty && (content == null || content!.isEmpty);

  bool get isUnread => status == MessageStatus.unread;

  /// Creates a [Message] from a Firestore document (encrypted data only).
  /// Decrypt locally and use [copyWith(content: decrypted)] for local storage.
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

  /// Serializes for Firestore: **encrypted data only** (zero-knowledge; no plaintext).
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

  /// For local/Hive only: full map including [content] (plaintext). Do not send to Firestore.
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'encryptedContent': encryptedContent,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.value,
      if (iv != null) 'iv': iv,
      if (preview != null) 'preview': preview,
      if (senderType != null) 'senderType': senderType,
    };
  }

  /// From local/Hive map (includes optional [content]).
  factory Message.fromLocalMap(Map<dynamic, dynamic> map) {
    final ts = map['timestamp'];
    DateTime dateTime = DateTime.now();
    if (ts != null) {
      if (ts is int) dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is num) dateTime = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
    }
    return Message(
      id: map['id'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      encryptedContent: map['encryptedContent'] as String? ?? '',
      content: map['content'] as String?,
      timestamp: dateTime,
      status: MessageStatusX.fromString(map['status'] as String?),
      iv: (map['iv'] as List<dynamic>?)?.cast<int>(),
      preview: map['preview'] as String?,
      senderType: map['senderType'] as String?,
    );
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? encryptedContent,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    List<int>? iv,
    String? preview,
    String? senderType,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      iv: iv ?? this.iv,
      preview: preview ?? this.preview,
      senderType: senderType ?? this.senderType,
    );
  }

  static DateTime _parseTimestamp(dynamic v, String docId, String field) {
    if (v == null) throw ArgumentError('Message $docId missing $field');
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    throw ArgumentError('Message $docId invalid $field type');
  }
}

/// Hive TypeAdapter for [Message] (local storage only; stores decrypted [content]).
class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 6;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final ts = fields[3];
    DateTime dateTime = DateTime.now();
    if (ts != null) {
      if (ts is int) dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is num) dateTime = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
    }
    return Message(
      id: fields[0] as String? ?? '',
      conversationId: fields[1] as String? ?? '',
      senderId: fields[2] as String? ?? '',
      timestamp: dateTime,
      encryptedContent: fields[4] as String? ?? '',
      status: MessageStatusX.fromString(fields[5] as String?),
      content: fields[6] as String?,
      iv: (fields[7] as List<dynamic>?)?.cast<int>(),
      preview: fields[8] as String?,
      senderType: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.timestamp.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.encryptedContent)
      ..writeByte(5)
      ..write(obj.status.value)
      ..writeByte(6)
      ..write(obj.content)
      ..writeByte(7)
      ..write(obj.iv)
      ..writeByte(8)
      ..write(obj.preview)
      ..writeByte(9)
      ..write(obj.senderType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
