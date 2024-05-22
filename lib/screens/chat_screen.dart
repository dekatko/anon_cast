import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:hive/hive.dart';
import 'package:pointycastle/api.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../provider/chat_session_provider.dart';
import '../provider/firestore_provider.dart';
import '../provider/user_provider.dart';
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
  final firestore = FirestoreProvider();

  final TextEditingController _messageController =
      TextEditingController(); // For user input

  @override
  void initState() {
    super.initState();
    // _generateEphemeralKeyPair();
    // Fetch messages for the chat room using chat_service.dart
    // _loadSessionFuture = _loadOrCreateChatSession(); // Preload the future
  }

  Future<void> _generateEphemeralKeyPair() async {
    _myEphemeralKeyPair = await _keyService.generateEphemeralKeyPair();
  }

  Future<ChatSession?> _loadOrCreateChatSession() async {
    final user = Provider.of<UserProvider>(context).user;
    final chatSessionProvider = Provider.of<ChatSessionProvider>(context, listen: false);

    try {
      final box = await Hive.openBox('chat_sessions');
      final sessionData = box.get(chatSessionProvider.chatSession?.id);

      if (sessionData != null) {
        log.i("");
        return ChatSession.fromMap(sessionData as Map); // Assuming a fromMap constructor
      } else {
        // No session found, create a new one
        // final currentUser = FirebaseAuth.instance.currentUser;
        if (user != null) {
          log.i("_loadOrCreateChatSession() - Creating new ChatSession");
          final newSession = ChatSession(
              id: const Uuid().v4(),
              studentId: user.id, // Use anonymous user's UID as username
              adminId: '',
              name: '',
              messages: [],
              startedAt: DateTime.now(),
              lastActive: DateTime.now()); // Set startedAt to current time
          await box.put(newSession.id, newSession.toMap()); // Save the new session
          chatSessionProvider.setChatSession(newSession);

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
      // Option 1: Store message content directly in Firestore (less secure)
      await firestore.firestore
          .collection('chatRooms') // Replace with appropriate collection name
          .doc('roomId') // Replace with actual chat room ID
          .collection('messages')
          .add({
        'content': messageContent,
        'senderId': FirebaseAuth.instance.currentUser?.uid, // Use anonymous user ID
        'timestamp': DateTime.now(), // Add timestamp for sorting
      });

      // Option 2: Store message reference (more secure)
      // final encryptedMessage = await _chatService._encryptMessage(
      //     messageContent, _myEphemeralKeyPair!.publicKey); // Assuming encryption logic
      await firestore.firestore
          .collection('chatRooms') // Replace with appropriate collection name
          .doc('roomId') // Replace with actual chat room ID
          .collection('messages')
          .add({
        'content': messageContent, // Encrypted message content
        'senderId': FirebaseAuth.instance.currentUser?.uid, // Use anonymous user ID
        'timestamp': DateTime.now(), // Add timestamp for sorting
      });

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
        title: const Text('Chat Room'),
      ),
      body: FutureBuilder<ChatSession?>(
        future: _loadOrCreateChatSession(), // Replace with your actual method call
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
