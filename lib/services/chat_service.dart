import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../models/chat_message.dart';
import '../utils/encryption_util.dart';

class ChatService {
  final String key; // Encryption key (assumed to be securely stored)

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

  Uint8List?
      _usedIv; // Stores the IV used for the last encryption (for message object)
}
