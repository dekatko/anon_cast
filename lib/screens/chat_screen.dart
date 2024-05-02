import 'package:flutter/material.dart';
import 'package:pointycastle/api.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/encryption_key_service.dart';

class ChatScreen extends StatefulWidget {
  ChatSession? _currentSession;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> messages = []; // List to store chat messages
  AsymmetricKeyPair<PublicKey, PrivateKey>? _myEphemeralKeyPair;
  final EncryptionKeyService _keyService = EncryptionKeyService();

  final TextEditingController _messageController =
      TextEditingController(); // For user input

  @override
  void initState() {
    super.initState();
    // _generateEphemeralKeyPair();
    // Fetch messages for the chat room using chat_service.dart
    _loadChatSession();
  }

  Future<void> _generateEphemeralKeyPair() async {
    _myEphemeralKeyPair = await _keyService.generateEphemeralKeyPair();
  }

  Future<void> _loadChatSession() async {
    // _currentSession = await HiveService
    //     .getChatSession(); // Or ChatSessionController.getChatSession()
  }

  void _sendMessage() async {
    String messageContent = _messageController.text.trim();
    if (messageContent.isNotEmpty) {
      // Create an instance of ChatService (assuming it has a constructor)
      // final chatService = ChatService();
      // Call sendMessage on the instance
      // await chatService.sendMessage(widget.chatRoomId, messageContent);
      _messageController.clear();
      // _getMessages(); // Refresh message list after sending
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat Room"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                // return ChatMessageTile(
                //     message: messages[
                //         index]); // Widget for displaying individual messages
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(hintText: "Enter message"),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
