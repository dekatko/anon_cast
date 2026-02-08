import 'package:anon_cast/models/conversation_key.dart';
import 'package:anon_cast/services/encryption_service.dart';

/// In-memory [ConversationKeyStorage] for unit tests (no Hive).
class InMemoryConversationKeyStorage implements ConversationKeyStorage {
  final Map<String, ConversationKey> _store = {};

  @override
  Future<void> store(String conversationId, ConversationKey key) async {
    _store[conversationId] = key;
  }

  @override
  Future<ConversationKey?> get(String conversationId) async => _store[conversationId];

  @override
  Future<bool> has(String conversationId) async => _store.containsKey(conversationId);

  @override
  Future<void> delete(String conversationId) async {
    _store.remove(conversationId);
  }
}
