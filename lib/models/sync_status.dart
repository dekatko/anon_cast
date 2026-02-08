/// Sync state of a message (for optimistic UI and offline queue).
enum SyncStatus {
  /// Message is in the send queue, not yet written to server.
  sending,
  /// Written to Firestore (or confirmed by server).
  sent,
  /// Optional: recipient/view has been acknowledged (e.g. read receipt).
  delivered,
  /// Send failed; will retry when back online.
  failed,
}

extension SyncStatusX on SyncStatus {
  String get value {
    switch (this) {
      case SyncStatus.sending:
        return 'sending';
      case SyncStatus.sent:
        return 'sent';
      case SyncStatus.delivered:
        return 'delivered';
      case SyncStatus.failed:
        return 'failed';
    }
  }

  static SyncStatus fromString(String? v) {
    switch (v) {
      case 'sent':
        return SyncStatus.sent;
      case 'delivered':
        return SyncStatus.delivered;
      case 'failed':
        return SyncStatus.failed;
      default:
        return SyncStatus.sending;
    }
  }

  bool get isPending => this == SyncStatus.sending || this == SyncStatus.failed;
  bool get isFailed => this == SyncStatus.failed;
}
