import '../models/message.dart';

/// Abstraction for message and key storage used by [MessageService].
/// Production: [LocalStorageService]; tests: in-memory implementation.
abstract interface class MessageServiceStorage {
  Future<void> storeMessage(Message message);
  Future<Message?> getMessage(String messageId);
  Future<List<Message>> getConversationMessages(String conversationId);
  Future<void> storeConversationKey(String conversationId, String key);
  Future<String?> getConversationKey(String conversationId);
  Future<void> deleteMessage(String messageId);
  Future<void> deleteConversation(String conversationId);
  Future<String?> getUserPref(String key);
  Future<void> setUserPref(String key, String value);
}
