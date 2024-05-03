import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:hive/hive.dart';
import 'package:pointycastle/api.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/chat_service.dart';
import '../services/encryption_key_service.dart';

final log = Logger();

class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Future<ChatSession?>? _loadSessionFuture;
  List<ChatMessage> messages = []; // List to store chat messages
  AsymmetricKeyPair<PublicKey, PrivateKey>? _myEphemeralKeyPair;
  final ChatService _chatService = ChatService("placeholder"); // Assuming ChatService instance
  final EncryptionKeyService _keyService = EncryptionKeyService();

  final TextEditingController _messageController =
      TextEditingController(); // For user input

  @override
  void initState() {
    super.initState();
    // _generateEphemeralKeyPair();
    // Fetch messages for the chat room using chat_service.dart
    _loadSessionFuture = _loadChatSession(); // Preload the future
  }

  Future<void> _generateEphemeralKeyPair() async {
    _myEphemeralKeyPair = await _keyService.generateEphemeralKeyPair();
  }

  Future<ChatSession?> _loadChatSession() async {
    try {
      final box = await Hive.openBox('chat_session');
      final sessionData = box.get('session');
      if (sessionData != null) {
        return ChatSession.fromMap(sessionData); // Assuming a fromMap constructor
      } else {
        return null;
      }
    } catch (error) {
      // Handle potential errors during session retrieval (optional)
      print('Error loading chat session: $error');
      return null;
    }
  }

  Future<ChatSession?> _loadOrCreateChatSession() async {
    try {
      final box = await Hive.openBox('chat_session');
      final sessionData = box.get('session');
      if (sessionData != null) {
        return ChatSession.fromMap(sessionData); // Assuming a fromMap constructor
      } else {
        // No session found, create a new one
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final newSession = ChatSession(
              username: currentUser.uid, // Use anonymous user's UID as username
              messages: [],
              startedAt: DateTime.now()); // Set startedAt to current time
          await box.put('session', newSession.toMap()); // Save the new session
          return newSession;
        } else {
          // Handle case where user is not logged in (optional)
          //Not necessarily needed, because anonymous users always login afresh
          print('Error: User not logged in');
          return null;
        }
      }
    } catch (error) {
      // Handle potential errors during session retrieval or creation (optional)
      print('Error loading/creating chat session: $error');
      return null;
    }
  }

  void _sendMessage() async {
    String messageContent = _messageController.text.trim();
    if (messageContent.isNotEmpty) {
      // Generate ephemeral key pair if not already generated. Null-Aware assignment used
      _myEphemeralKeyPair ??= await _keyService.generateEphemeralKeyPair();
      // Call sendMessage on the chat service instance
      await _chatService.sendMessage(
          messageContent, _myEphemeralKeyPair!.publicKey); // Assuming arguments
      _messageController.clear();
      // Refresh message list after sending (consider using a provider/bloc for updates)
      _loadSessionFuture = _loadOrCreateChatSession(); // Reload session data
      setState(() {}); // Trigger a rebuild to reflect changes
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Room"),
      ),
      body: FutureBuilder<ChatSession?>(
        future: _loadChatSession(), // Replace with your actual method call
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final session = snapshot.data!;
            // Access messages from the loaded session
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: session.messages.length, // Use messages from session
                    itemBuilder: (context, index) {
                      final message = session.messages[index];
                      // return ChatMessageTile(message: message); // Widget for displaying messages
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
            );
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading session'));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
