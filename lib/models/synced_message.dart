import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_message.dart';
import 'sync_status.dart';

/// A message with sync state for offline queue and optimistic UI.
class SyncedMessage {
  const SyncedMessage({
    required this.message,
    this.syncStatus = SyncStatus.sent,
    this.localId,
  });

  final AdminMessage message;
  final SyncStatus syncStatus;
  /// Set for pending/unsent messages (client-generated id before server doc id).
  final String? localId;

  String get id => message.id;
  String get conversationId => message.conversationId;

  /// From Firestore doc (always [SyncStatus.sent]).
  factory SyncedMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String? currentAdminUid,
  ) {
    final msg = AdminMessage.fromFirestoreWithSenderType(doc, currentAdminUid);
    return SyncedMessage(message: msg, syncStatus: SyncStatus.sent);
  }

  /// From pending queue (map stored in Hive).
  factory SyncedMessage.fromPendingMap(Map<dynamic, dynamic> map, String localId) {
    final ts = map['timestamp'];
    DateTime dateTime = DateTime.now();
    if (ts != null) {
      if (ts is int) dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is num) dateTime = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
    }
    final msg = AdminMessage(
      id: localId,
      conversationId: map['conversationId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      encryptedContent: map['encryptedContent'] as String? ?? '',
      timestamp: dateTime,
      status: MessageStatusX.fromString(map['status'] as String?),
      iv: (map['iv'] as List<dynamic>?)?.cast<int>(),
      preview: map['preview'] as String?,
      senderType: map['senderType'] as String?,
    );
    final status = SyncStatusX.fromString(map['syncStatus'] as String?);
    return SyncedMessage(message: msg, syncStatus: status, localId: localId);
  }

  SyncedMessage copyWith({
    AdminMessage? message,
    SyncStatus? syncStatus,
    String? localId,
  }) {
    return SyncedMessage(
      message: message ?? this.message,
      syncStatus: syncStatus ?? this.syncStatus,
      localId: localId ?? this.localId,
    );
  }
}
