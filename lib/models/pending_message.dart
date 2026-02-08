import 'package:hive/hive.dart';

/// Status of a message in the offline send queue.
enum PendingMessageStatus {
  pending,
  sending,
  failed,
  sent,
}

extension PendingMessageStatusX on PendingMessageStatus {
  String get value {
    switch (this) {
      case PendingMessageStatus.pending:
        return 'pending';
      case PendingMessageStatus.sending:
        return 'sending';
      case PendingMessageStatus.failed:
        return 'failed';
      case PendingMessageStatus.sent:
        return 'sent';
    }
  }

  static PendingMessageStatus fromString(String? v) {
    switch (v) {
      case 'sending':
        return PendingMessageStatus.sending;
      case 'failed':
        return PendingMessageStatus.failed;
      case 'sent':
        return PendingMessageStatus.sent;
      default:
        return PendingMessageStatus.pending;
    }
  }
}

/// A message queued for send when offline or after send failure.
/// Stored in Hive box 'pending_messages'. Encryption is done before queueing.
class PendingMessage {
  const PendingMessage({
    required this.id,
    required this.conversationId,
    required this.encryptedContent,
    required this.iv,
    required this.timestamp,
    this.retryCount = 0,
    this.status = PendingMessageStatus.pending,
    this.senderId = '',
    this.senderType,
    this.preview,
    this.lastError,
    this.nextRetryAt,
  });

  final String id;
  final String conversationId;
  final String encryptedContent;
  final List<int> iv;
  final DateTime timestamp;
  final int retryCount;
  final PendingMessageStatus status;
  final String senderId;
  final String? senderType;
  final String? preview;
  final String? lastError;
  /// When set, processQueue will skip this message until after this time (exponential backoff).
  final DateTime? nextRetryAt;

  bool get isPending => status == PendingMessageStatus.pending;
  bool get isSending => status == PendingMessageStatus.sending;
  bool get isFailed => status == PendingMessageStatus.failed;
  bool get isSent => status == PendingMessageStatus.sent;

  PendingMessage copyWith({
    String? id,
    String? conversationId,
    String? encryptedContent,
    List<int>? iv,
    DateTime? timestamp,
    int? retryCount,
    PendingMessageStatus? status,
    String? senderId,
    String? senderType,
    String? preview,
    String? lastError,
    DateTime? nextRetryAt,
  }) {
    return PendingMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      iv: iv ?? this.iv,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      preview: preview ?? this.preview,
      lastError: lastError ?? this.lastError,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }
}

/// Hive TypeAdapter for [PendingMessage] (box: pending_messages).
class PendingMessageAdapter extends TypeAdapter<PendingMessage> {
  @override
  final int typeId = 8;

  @override
  PendingMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final ts = fields[4];
    DateTime dateTime = DateTime.now();
    if (ts != null) {
      if (ts is int) dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is num) dateTime = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
    }
    final nextTs = fields[11];
    DateTime? nextRetryAt;
    if (nextTs != null) {
      if (nextTs is int) nextRetryAt = DateTime.fromMillisecondsSinceEpoch(nextTs);
      if (nextTs is num) nextRetryAt = DateTime.fromMillisecondsSinceEpoch(nextTs.toInt());
    }
    return PendingMessage(
      id: fields[0] as String? ?? '',
      conversationId: fields[1] as String? ?? '',
      encryptedContent: fields[2] as String? ?? '',
      iv: (fields[3] as List<dynamic>?)?.cast<int>() ?? [],
      timestamp: dateTime,
      retryCount: fields[5] as int? ?? 0,
      status: PendingMessageStatusX.fromString(fields[6] as String?),
      senderId: fields[7] as String? ?? '',
      senderType: fields[8] as String?,
      preview: fields[9] as String?,
      lastError: fields[10] as String?,
      nextRetryAt: nextRetryAt,
    );
  }

  @override
  void write(BinaryWriter writer, PendingMessage obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.encryptedContent)
      ..writeByte(3)
      ..write(obj.iv)
      ..writeByte(4)
      ..write(obj.timestamp.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.retryCount)
      ..writeByte(6)
      ..write(obj.status.value)
      ..writeByte(7)
      ..write(obj.senderId)
      ..writeByte(8)
      ..write(obj.senderType)
      ..writeByte(9)
      ..write(obj.preview)
      ..writeByte(10)
      ..write(obj.lastError)
      ..writeByte(11)
      ..write(obj.nextRetryAt?.millisecondsSinceEpoch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingMessageAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
