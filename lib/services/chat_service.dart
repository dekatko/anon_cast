import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../utils/encryption_util.dart';

final log = Logger();

class ChatService {
  final String key; // Encryption key (assumed to be securely stored)
  final CollectionReference _chatSessions =
      FirebaseFirestore.instance.collection('chat_sessions');
  final CollectionReference _admins =
      FirebaseFirestore.instance.collection('administrators');

  ChatService(this.key);

  Future<ChatMessage> sendMessage(String content, String recipientId) async {
    final encryptedContent = await _encryptMessage(content);
    final message = ChatMessage(
      id: '...',
      // Generate a unique ID for the message
      senderId: '...',
      // Sender ID (current user)
      encryptedContent: encryptedContent,
      timestamp: DateTime.now().toString(),
      iv: _usedIv, // Store the used IV in the message
    );

    // Store the message in the database (implementation omitted)
    // await storeMessage(message);

    return message;
  }

  Future<void> saveMessage(ChatMessage message) async {
    final box = await Hive.openBox('chat_messages');
    // Generate a unique ID for the message (optional)
    // message.id = "${DateTime.now().millisecondsSinceEpoch}-${message.hashCode}";
    await box.add(message);
  }

  // Future<ChatMessage> getMessage(String messageId) async {
  //   final message = await retrieveMessage(
  //       messageId); // Fetch message from database (implementation omitted)
  //
  //   final decryptedContent =
  //       await _decryptMessage(message.encryptedContent, message.iv);
  //   return message.copyWith(
  //       content:
  //           decryptedContent); // Replace encryptedContent with decrypted content
  // }

  Future<String> _encryptMessage(String message) async {
    final iv = EncryptionUtil.generateRandomBytes(16);
    final encryptedBytes = EncryptionUtil.encrypt(message, key, iv);
    _usedIv = iv; // Store the used IV for later decryption
    return encryptedBytes;
  }

  Future<ChatSession?> getExistingOrNewChat(
      String anonymousUserId, String adminCode) async {
    final snapshotAdmin = await _findAdminByCode(adminCode);

    if (null == snapshotAdmin) {
      log.i("Admin Code does not exist!");
      return null;
    }

    final adminId = snapshotAdmin.id;
    return getExistingOrNewChatByAdminId(anonymousUserId, adminId);
  }

  /// Find or create a chat session between [anonymousUserId] and the admin
  /// with Firestore document id [adminId] (administrators collection).
  Future<ChatSession?> getExistingOrNewChatByAdminId(
      String anonymousUserId, String adminId) async {
    final snapshotChatSessions = await _chatSessions
        .where('participants', arrayContains: anonymousUserId)
        .get();

    if (snapshotChatSessions.docs.isNotEmpty) {
      final filteredSessions = snapshotChatSessions.docs
          .where((doc) => doc.get('participants').contains(adminId))
          .toList();
      if (filteredSessions.isNotEmpty) {
        final chatData = filteredSessions.first.data();
        log.i("ChatSession found. Returning...");
        return ChatSession.fromMap(
            chatData as Map<dynamic, dynamic>);
      }
    }

    log.i("No existing chat found, creating new chat...");
    return createChatByAdminId(anonymousUserId, adminId);
  }

  Future<ChatSession> createChatByAdminId(
      String anonymousUserId, String adminId) async {
    final chatId = _chatSessions.doc().id;
    final newChat = ChatSession.create(anonymousUserId, adminId);
    await _chatSessions.doc(chatId).set(newChat.toMap());
    await _chatSessions.doc(chatId).update({
      'participants': FieldValue.arrayUnion([anonymousUserId, adminId]),
    });
    return newChat;
  }

  Future<ChatSession> createChat(
      String anonymousUserId, String adminCode) async {
    final adminData = await _findAdminByCode(adminCode);
    if (adminData == null) {
      throw Exception('Invalid admin code');
    }
    return createChatByAdminId(anonymousUserId, adminData.id);
  }

  Future<DocumentSnapshot?> _findAdminByCode(String adminCode) async {
    final snapshot =
        await _admins.where('adminCode', isEqualTo: adminCode).get();
    return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
  }

  Uint8List?
      _usedIv; // Stores the IV used for the last encryption (for message object)
}
