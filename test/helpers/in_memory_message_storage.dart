import 'package:anon_cast/models/conversation_key.dart';
import 'package:anon_cast/models/message.dart';
import 'package:anon_cast/services/message_storage_interface.dart';

/// In-memory [MessageServiceStorage] for unit tests (no Hive).
class InMemoryMessageStorage implements MessageServiceStorage {
  final Map<String, Message> _messages = {};
  final Map<String, ConversationKey> _conversationKeys = {};
  final Map<String, String> _userPrefs = {};

  @override
  Future<void> storeMessage(Message message) async {
    _messages[message.id] = message;
  }

  @override
  Future<Message?> getMessage(String messageId) async => _messages[messageId];

  @override
  Future<List<Message>> getConversationMessages(String conversationId) async {
    final list = _messages.values
        .where((m) => m.conversationId == conversationId)
        .toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  @override
  Future<void> storeConversationKey(String conversationId, String key) async {
    final now = DateTime.now();
    _conversationKeys[conversationId] = ConversationKey(
      id: conversationId,
      key: key,
      createdAt: now,
      lastRotated: now,
    );
  }

  @override
  Future<String?> getConversationKey(String conversationId) async =>
      _conversationKeys[conversationId]?.key;

  @override
  Future<ConversationKey?> getConversationKeyFull(String conversationId) async =>
      _conversationKeys[conversationId];

  @override
  Future<void> storeConversationKeyFull(
      String conversationId, ConversationKey key) async {
    _conversationKeys[conversationId] = key;
  }

  @override
  Future<Map<String, String>> getAllConversationKeys() async {
    final map = <String, String>{};
    for (final e in _conversationKeys.entries) {
      if (e.value.key.isNotEmpty) map[e.key] = e.value.key;
    }
    return map;
  }

  @override
  Future<List<String>> getAllMessageIds() async => _messages.keys.toList();

  @override
  Future<void> deleteMessage(String messageId) async {
    _messages.remove(messageId);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    _messages.removeWhere((_, m) => m.conversationId == conversationId);
    _conversationKeys.remove(conversationId);
  }

  @override
  Future<void> deleteConversationKey(String conversationId) async {
    _conversationKeys.remove(conversationId);
  }

  @override
  Future<void> updateMessageId(String oldId, String newId) async {
    final m = _messages.remove(oldId);
    if (m != null) _messages[newId] = m.copyWith(id: newId);
  }

  @override
  Future<void> removePendingMessageId(String conversationId, String messageId) async {}

  @override
  Future<String?> getUserPref(String key) async => _userPrefs[key];

  @override
  Future<void> setUserPref(String key, String value) async {
    _userPrefs[key] = value;
  }

  void clear() {
    _messages.clear();
    _conversationKeys.clear();
    _userPrefs.clear();
  }
}
