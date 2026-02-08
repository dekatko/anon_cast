import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite schema version; bump when changing tables.
const int kDbVersion = 1;

/// Table: messages – cached messages for offline read.
const String kTableMessages = 'messages';
const String kColId = 'id';
const String kColConversationId = 'conversation_id';
const String kColSenderId = 'sender_id';
const String kColEncryptedContent = 'encrypted_content';
const String kColTimestamp = 'timestamp';
const String kColStatus = 'status';
const String kColIv = 'iv';
const String kColPreview = 'preview';
const String kColSenderType = 'sender_type';
const String kColSyncedAt = 'synced_at';

/// Table: conversations – cached conversation metadata.
const String kTableConversations = 'conversations';
const String kColOrganizationId = 'organization_id';
const String kColAdminId = 'admin_id';
const String kColAnonymousUserId = 'anonymous_user_id';
const String kColCreatedAt = 'created_at';
const String kColUpdatedAt = 'updated_at';
const String kColLastMessageAt = 'last_message_at';
const String kColTypingAdmin = 'typing_admin';
const String kColTypingAnonymous = 'typing_anonymous';

/// Table: pending_operations – queue for send/update operations when offline.
const String kTablePendingOps = 'pending_operations';
const String kColOpId = 'id';
const String kColOpType = 'type';
const String kColPayload = 'payload';
const String kColCreatedAtOp = 'created_at';
const String kColRetryCount = 'retry_count';
const String kColLastError = 'last_error';
const String kColOpStatus = 'status';

/// Pending operation types.
const String kOpTypeSendMessage = 'send_message';
const String kOpTypeUpdateMessageStatus = 'update_message_status';

/// Operation status.
const String kOpStatusPending = 'pending';
const String kOpStatusSyncing = 'syncing';
const String kOpStatusCompleted = 'completed';
const String kOpStatusFailed = 'failed';

/// Singleton app database (sqflite). Use [instance] and call [init] before use.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase _instance = AppDatabase._();
  static AppDatabase get instance => _instance;

  Database? _db;
  final _initCompleter = Completer<void>();

  /// Initialize database; safe to call multiple times.
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await _databasePath();
    _db = await openDatabase(
      dbPath,
      version: kDbVersion,
      onCreate: _onCreate,
    );
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<String> _databasePath() async {
    final basePath = await _getDatabasesPath();
    return join(basePath, 'anon_cast_offline.db');
  }

  Future<String> _getDatabasesPath() async {
    try {
      final path = await getDatabasesPath();
      return path;
    } catch (_) {
      return '';
    }
  }

  Database get db {
    final d = _db;
    if (d == null) throw StateError('AppDatabase not initialized. Call init() first.');
    return d;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $kTableMessages (
        $kColId TEXT PRIMARY KEY,
        $kColConversationId TEXT NOT NULL,
        $kColSenderId TEXT NOT NULL,
        $kColEncryptedContent TEXT NOT NULL,
        $kColTimestamp INTEGER NOT NULL,
        $kColStatus TEXT NOT NULL,
        $kColIv BLOB,
        $kColPreview TEXT,
        $kColSenderType TEXT,
        $kColSyncedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_messages_conversation ON $kTableMessages($kColConversationId)
    ''');
    await db.execute('''
      CREATE INDEX idx_messages_timestamp ON $kTableMessages($kColTimestamp)
    ''');

    await db.execute('''
      CREATE TABLE $kTableConversations (
        $kColId TEXT PRIMARY KEY,
        $kColOrganizationId TEXT NOT NULL,
        $kColAdminId TEXT NOT NULL,
        $kColAnonymousUserId TEXT NOT NULL,
        $kColCreatedAt INTEGER NOT NULL,
        $kColUpdatedAt INTEGER,
        $kColLastMessageAt INTEGER,
        $kColTypingAdmin INTEGER,
        $kColTypingAnonymous INTEGER,
        $kColSyncedAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $kTablePendingOps (
        $kColOpId INTEGER PRIMARY KEY AUTOINCREMENT,
        $kColOpType TEXT NOT NULL,
        $kColPayload TEXT NOT NULL,
        $kColCreatedAtOp INTEGER NOT NULL,
        $kColRetryCount INTEGER NOT NULL DEFAULT 0,
        $kColLastError TEXT,
        $kColOpStatus TEXT NOT NULL DEFAULT '$kOpStatusPending'
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_pending_ops_status ON $kTablePendingOps($kColOpStatus)
    ''');
  }

  /// Ensure init has completed (e.g. when path is resolved asynchronously).
  Future<void> get ready => _initCompleter.isCompleted ? Future.value() : _initCompleter.future;

  void close() {
    _db?.close();
    _db = null;
  }
}
