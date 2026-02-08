import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an anonymous message as seen by the admin.
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

/// Represents a message document from Firestore collection 'messages'.
/// Used by the admin dashboard for listing and filtering.
class AdminMessage {
  const AdminMessage({
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
  /// Optional short preview (e.g. decrypted first 50 chars or placeholder).
  final String? preview;
  /// 'admin' or 'anonymous'. Used for thread UI.
  final String? senderType;

  bool get isUnread => status == MessageStatus.unread;
  bool get isFromAdmin => senderType == 'admin';

  factory AdminMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['timestamp'];
    DateTime dateTime = DateTime.now();
    if (ts is Timestamp) {
      dateTime = ts.toDate();
    } else if (ts is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    return AdminMessage(
      id: doc.id,
      conversationId: data['conversationId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      encryptedContent: data['encryptedContent'] as String? ?? '',
      timestamp: dateTime,
      status: MessageStatusX.fromString(data['status'] as String?),
      iv: (data['iv'] as List<dynamic>?)?.cast<int>(),
      preview: data['preview'] as String?,
      senderType: data['senderType'] as String?,
    );
  }

  /// Use in thread screen when current user (admin) uid is known to derive senderType.
  factory AdminMessage.fromFirestoreWithSenderType(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String? currentAdminUid,
  ) {
    final msg = AdminMessage.fromFirestore(doc);
    final data = doc.data() ?? <String, dynamic>{};
    final type = data['senderType'] as String?;
    final sid = data['senderId'] as String? ?? '';
    final isAdmin = type == 'admin' || (currentAdminUid != null && sid == currentAdminUid);
    return AdminMessage(
      id: msg.id,
      conversationId: msg.conversationId,
      senderId: msg.senderId,
      encryptedContent: msg.encryptedContent,
      timestamp: msg.timestamp,
      status: msg.status,
      iv: msg.iv,
      preview: msg.preview,
      senderType: isAdmin ? 'admin' : 'anonymous',
    );
  }

  /// Serializes for Firestore (uses [Timestamp] for timestamp).
  Map<String, dynamic> toFirestore() => toMap();

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'encryptedContent': encryptedContent,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.value,
      if (iv != null) 'iv': iv,
      if (preview != null) 'preview': preview,
      if (senderType != null) 'senderType': senderType,
    };
  }

  AdminMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? encryptedContent,
    DateTime? timestamp,
    MessageStatus? status,
    List<int>? iv,
    String? preview,
    String? senderType,
  }) {
    return AdminMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      iv: iv ?? this.iv,
      preview: preview ?? this.preview,
      senderType: senderType ?? this.senderType,
    );
  }
}
