/// UI state for a message regarding offline/sync: cached locally, syncing, or synced.
enum OfflineMessageState {
  /// Only in local cache, not yet confirmed by server.
  cached,
  /// Currently being sent or synced.
  syncing,
  /// Confirmed on server.
  synced,
}

extension OfflineMessageStateX on OfflineMessageState {
  String get label {
    switch (this) {
      case OfflineMessageState.cached:
        return 'Cached';
      case OfflineMessageState.syncing:
        return 'Syncing…';
      case OfflineMessageState.synced:
        return 'Synced';
    }
  }
}
