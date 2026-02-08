import '../models/conversation_key.dart';
import '../models/message.dart';

/// Abstraction for message and key storage used by [MessageService].
/// Production: [LocalStorageService]; tests: in-memory implementation.
abstract interface class MessageServiceStorage {
  Future<void> storeMessage(Message message);
  Future<Message?> getMessage(String messageId);
  Future<List<Message>> getConversationMessages(String conversationId);
  Future<void> storeConversationKey(String conversationId, String key);
  Future<String?> getConversationKey(String conversationId);
  /// Full key object (version, oldKeys) for rotation and versioned decryption.
  Future<ConversationKey?> getConversationKeyFull(String conversationId);
  /// Store full key (e.g. after rotation).
  Future<void> storeConversationKeyFull(String conversationId, ConversationKey key);
  /// All conversation keys (id -> base64 key). For export and secure wipe.
  Future<Map<String, String>> getAllConversationKeys();
  /// All message IDs in storage. For secure wipe.
  Future<List<String>> getAllMessageIds();
  Future<void> deleteMessage(String messageId);
  Future<void> deleteConversation(String conversationId);
  /// Deletes only the conversation key (not messages). For secure deletion overwrite-then-delete flow.
  Future<void> deleteConversationKey(String conversationId);
  /// Replaces local message id with server id after successful sync. Use when a queued message is sent.
  Future<void> updateMessageId(String oldId, String newId);
  /// Removes a message id from the MessageService pending list for [conversationId].
  Future<void> removePendingMessageId(String conversationId, String messageId);
  Future<String?> getUserPref(String key);
  Future<void> setUserPref(String key, String value);
}
