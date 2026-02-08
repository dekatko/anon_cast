/// Logged rotation event for admin monitoring.
enum RotationEventType {
  started,
  progress,
  completed,
  failed,
  rolledBack,
}

/// A single rotation event (for admin dashboard and debugging).
class RotationEvent {
  final String conversationId;
  final RotationEventType type;
  final DateTime at;
  final String message;
  final int? messagesProcessed;
  final int? messagesTotal;
  final String? error;

  const RotationEvent({
    required this.conversationId,
    required this.type,
    required this.at,
    required this.message,
    this.messagesProcessed,
    this.messagesTotal,
    this.error,
  });

  Map<String, dynamic> toMap() => {
        'conversationId': conversationId,
        'type': type.name,
        'at': at.toIso8601String(),
        'message': message,
        if (messagesProcessed != null) 'messagesProcessed': messagesProcessed,
        if (messagesTotal != null) 'messagesTotal': messagesTotal,
        if (error != null) 'error': error,
      };
}
