/// In-memory mock of Firestore message storage for integration tests.
/// Maps conversationId -> list of message documents (as Map).
/// Simulates: set(docId, data), get(docId), list(conversationId).
class MockFirestoreMessages {
  /// conversationId -> list of { 'id', 'senderId', 'encryptedContent', 'timestamp', 'iv' }
  final Map<String, List<Map<String, dynamic>>> _collections = {};

  /// Adds a message document to the given conversation (like Firestore set).
  Future<void> setMessage(String conversationId, Map<String, dynamic> data) async {
    final list = _collections.putIfAbsent(conversationId, () => []);
    final id = data['id'] as String? ?? 'msg-${list.length}';
    final withId = Map<String, dynamic>.from(data)..['id'] = id;
    list.add(withId);
  }

  /// Gets a message by conversationId and message index (no real doc IDs in mock).
  Map<String, dynamic>? getMessage(String conversationId, int index) {
    final list = _collections[conversationId];
    if (list == null || index < 0 || index >= list.length) return null;
    return list[index];
  }

  /// Gets all messages for a conversation (like Firestore get where conversationId == X).
  List<Map<String, dynamic>> getMessages(String conversationId) {
    return List.from(_collections[conversationId] ?? []);
  }

  /// Returns all conversation IDs that have at least one message.
  List<String> get conversationIds => _collections.keys.toList();

  /// Clears all data (for teardown).
  void clear() => _collections.clear();
}
