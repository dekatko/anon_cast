import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../models/conversation_key.dart';
import '../models/message.dart';
import '../models/pending_message.dart';
import 'message_storage_interface.dart';

/// Box names for local storage. Data is stored in app documents directory
/// (cleared by OS on app uninstall for privacy).
class LocalStorageService implements MessageServiceStorage {
  LocalStorageService._({Logger? logger}) : _log = logger ?? Logger();
  static final LocalStorageService _instance = LocalStorageService._();
  static LocalStorageService get instance => _instance;

  static const String _boxMessages = 'messages';
  static const String _boxConversationKeys = 'conversation_keys';
  static const String _boxUserPrefs = 'user_prefs';
  static const String _pendingPrefPrefix = 'message_service_pending_';

  final Logger _log;
  bool _initialized = false;
  static bool _hiveInited = false;

  Box<Message>? _messagesBox;
  Box<ConversationKey>? _conversationKeysBox;
  Box<String>? _userPrefsBox;

  /// Initialize Hive with path_provider directory (app documents dir; cleared on uninstall),
  /// register adapters, open boxes. Safe to call multiple times; subsequent calls no-op.
  /// On web, uses [Hive.initFlutter].
  Future<void> init() async {
    if (_initialized) return;
    try {
      if (!_hiveInited) {
        if (kIsWeb) {
          await Hive.initFlutter();
        } else {
          final dir = await getApplicationDocumentsDirectory();
          Hive.init(dir.path);
          _log.d('LocalStorageService: Hive initialized at ${dir.path}');
        }
        _hiveInited = true;
      }

      _registerAdapters();
      await _openBoxes();
      _initialized = true;
      _log.d('LocalStorageService: init complete');
    } catch (e, st) {
      _log.e('LocalStorageService: init failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(MessageAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ConversationKeyAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(PendingMessageAdapter());
    }
  }

  Future<void> _openBoxes() async {
    _messagesBox ??= await Hive.openBox<Message>(_boxMessages);
    _conversationKeysBox ??= await Hive.openBox<ConversationKey>(_boxConversationKeys);
    _userPrefsBox ??= await Hive.openBox<String>(_boxUserPrefs);
  }

  Box<Message> get _messages {
    final b = _messagesBox;
    if (b == null) throw StateError('LocalStorageService not initialized. Call init() first.');
    return b;
  }

  Box<ConversationKey> get _conversationKeys {
    final b = _conversationKeysBox;
    if (b == null) throw StateError('LocalStorageService not initialized. Call init() first.');
    return b;
  }

  Box<String> get _userPrefs {
    final b = _userPrefsBox;
    if (b == null) throw StateError('LocalStorageService not initialized. Call init() first.');
    return b;
  }

  /// Saves a decrypted [Message] to local storage (key = message.id).
  Future<void> storeMessage(Message message) async {
    if (!_initialized) await init();
    try {
      await _messages.put(message.id, message);
      _log.d('LocalStorageService: stored message ${message.id}');
    } catch (e, st) {
      _log.e('LocalStorageService: storeMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Deletes a message by [messageId] from local storage.
  Future<void> deleteMessage(String messageId) async {
    if (!_initialized) await init();
    try {
      await _messages.delete(messageId);
      _log.d('LocalStorageService: deleted message $messageId');
    } catch (e, st) {
      _log.e('LocalStorageService: deleteMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Retrieves a message by [messageId], or null if not found.
  Future<Message?> getMessage(String messageId) async {
    if (!_initialized) await init();
    try {
      return _messages.get(messageId);
    } catch (e, st) {
      _log.e('LocalStorageService: getMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Returns all messages for [conversationId], sorted by timestamp ascending.
  Future<List<Message>> getConversationMessages(String conversationId) async {
    if (!_initialized) await init();
    try {
      final list = _messages.values
          .where((m) => m.conversationId == conversationId)
          .toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    } catch (e, st) {
      _log.e('LocalStorageService: getConversationMessages failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Saves a conversation key (base64) for [conversationId]. Keys never leave the device.
  Future<void> storeConversationKey(String conversationId, String key) async {
    if (!_initialized) await init();
    if (conversationId.isEmpty) {
      throw ArgumentError('conversationId must not be empty');
    }
    try {
      final now = DateTime.now();
      await _conversationKeys.put(
        conversationId,
        ConversationKey(id: conversationId, key: key, createdAt: now, lastRotated: now),
      );
      _log.d('LocalStorageService: stored key for $conversationId');
    } catch (e, st) {
      _log.e('LocalStorageService: storeConversationKey failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Retrieves the base64 key for [conversationId], or null if not found.
  Future<String?> getConversationKey(String conversationId) async {
    if (!_initialized) await init();
    try {
      final ck = _conversationKeys.get(conversationId);
      return ck?.key;
    } catch (e, st) {
      _log.e('LocalStorageService: getConversationKey failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Returns all conversation keys (id -> base64 key). Used for key export/backup.
  Future<Map<String, String>> getAllConversationKeys() async {
    if (!_initialized) await init();
    try {
      final map = <String, String>{};
      for (final key in _conversationKeys.keys) {
        final ck = _conversationKeys.get(key);
        if (ck != null && ck.key.isNotEmpty) {
          map[ck.id] = ck.key;
        }
      }
      return map;
    } catch (e, st) {
      _log.e('LocalStorageService: getAllConversationKeys failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  static const String _boxPendingMessages = 'pending_messages';

  /// Privacy: wipes all local data (messages, keys, user_prefs, pending_messages). Call on logout.
  /// Boxes are cleared and closed; they will be reopened on next [init] or access.
  Future<void> clearAllData() async {
    if (!_initialized) return;
    try {
      await _messages.clear();
      await _conversationKeys.clear();
      await _userPrefs.clear();
      try {
        if (!Hive.isBoxOpen(_boxPendingMessages)) {
          await Hive.openBox<PendingMessage>(_boxPendingMessages);
        }
        final pendingBox = Hive.box<PendingMessage>(_boxPendingMessages);
        await pendingBox.clear();
        await pendingBox.close();
      } catch (e) {
        _log.w('LocalStorageService: clear pending_messages failed', error: e);
      }
      await _messages.close();
      await _conversationKeys.close();
      await _userPrefs.close();
      _messagesBox = null;
      _conversationKeysBox = null;
      _userPrefsBox = null;
      _initialized = false;
      _log.d('LocalStorageService: clearAllData complete (privacy wipe)');
    } catch (e, st) {
      _log.e('LocalStorageService: clearAllData failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Replaces local message id with server id (e.g. after offline queue sync).
  Future<void> updateMessageId(String oldId, String newId) async {
    if (!_initialized) await init();
    if (oldId.isEmpty || newId.isEmpty) return;
    try {
      final existing = _messages.get(oldId);
      if (existing == null) return;
      final updated = existing.copyWith(id: newId);
      await _messages.delete(oldId);
      await _messages.put(newId, updated);
      await removePendingMessageId(existing.conversationId, oldId);
      _log.d('LocalStorageService: updated message id $oldId -> $newId');
    } catch (e, st) {
      _log.e('LocalStorageService: updateMessageId failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> removePendingMessageId(String conversationId, String messageId) async {
    if (!_initialized) await init();
    final key = '$_pendingPrefPrefix$conversationId';
    final json = await getUserPref(key);
    if (json == null || json.isEmpty) return;
    try {
      final list = List<String>.from(jsonDecode(json) as List<dynamic>);
      list.remove(messageId);
      await setUserPref(key, list.isEmpty ? '' : jsonEncode(list));
    } catch (e, st) {
      _log.e('LocalStorageService: removePendingMessageId failed', error: e, stackTrace: st);
    }
  }

  /// Removes all messages and the key for [conversationId].
  Future<void> deleteConversation(String conversationId) async {
    if (!_initialized) await init();
    if (conversationId.isEmpty) return;
    try {
      final toRemove = _messages.keys
          .where((key) {
            final m = _messages.get(key);
            return m != null && m.conversationId == conversationId;
          })
          .toList();
      for (final key in toRemove) {
        await _messages.delete(key);
      }
      await _conversationKeys.delete(conversationId);
      _log.d('LocalStorageService: deleted conversation $conversationId (${toRemove.length} messages)');
    } catch (e, st) {
      _log.e('LocalStorageService: deleteConversation failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Optional: get/set string user preference (e.g. theme, locale).
  Future<void> setUserPref(String key, String value) async {
    if (!_initialized) await init();
    await _userPrefs.put(key, value);
  }

  Future<String?> getUserPref(String key) async {
    if (!_initialized) await init();
    return _userPrefs.get(key);
  }
}
