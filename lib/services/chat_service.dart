import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../utils/encryption_util.dart';

class ChatService {
  final String key; // Encryption key (assumed to be securely stored)
  final CollectionReference _chat_sessions = FirebaseFirestore.instance.collection('chat_sessions');
  final CollectionReference _admins = FirebaseFirestore.instance.collection('administrators');

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

  Future<String> _decryptMessage(String encryptedContent, Uint8List? iv) async {
    if (iv == null) {
      throw Exception('Missing initialization vector for decryption');
    }
    return EncryptionUtil.decrypt(
        encryptedContent, base64Decode(key), key, iv.toList());
  }

  Future<ChatSession?> checkForExistingChat(String anonymousUserId, String adminCode) async {
    // Query Firestore for chats where anonymousUserId is a participant
    // and the adminCode matches the administrator's code
    final snapshotChatSessions = await _chat_sessions.where('participants', arrayContains: anonymousUserId).get();

    final snapshotAdmin = _findAdminByCode(adminCode);

    if (snapshotChatSessions.docs.isNotEmpty && snapshotAdmin != null) {
      // Existing chat found, return the first chat data
      final chatData = snapshotChatSessions.docs.first.data();
      return ChatSession.fromMap(chatData as Map<dynamic, dynamic>); // Convert data to Chat object
    } else {
      return null; // No existing chat found between user and admin
    }
  }

  Future<ChatSession> createChat(String anonymousUserId, String adminCode) async {
    // 1. Verify adminCode and retrieve AdminId
    final adminData = await _findAdminByCode(adminCode);
    if (adminData == null) {
      throw Exception('Invalid admin code'); // Handle invalid code error
    }
    final adminId = adminData.id;

    // 2. Create a new chat document with participants and adminId
    final chatId = _chat_sessions.doc().id;
    final newChat = ChatSession.create(anonymousUserId, adminId);

    // 3. Save chat data and participant references
    await _chat_sessions.doc(chatId).set(newChat.toMap());
    await _chat_sessions.doc(chatId).update({
      'participants': FieldValue.arrayUnion([anonymousUserId, adminId]),
    });

    return newChat; // Return the created ChatSession object
  }

  Future<DocumentSnapshot?> _findAdminByCode(String adminCode) async {
    final snapshot = await _admins.where('adminCode', isEqualTo: adminCode).get();
    return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
  }

  Uint8List?
      _usedIv; // Stores the IV used for the last encryption (for message object)
}
