import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';

import '../models/chat_session.dart';

class AdministratorChatDashboardScreen extends StatefulWidget {
  const AdministratorChatDashboardScreen({super.key});

  @override
  _AdministratorChatDashboardScreenState createState() => _AdministratorChatDashboardScreenState();
}

class _AdministratorChatDashboardScreenState extends State<AdministratorChatDashboardScreen> {
  final _chatBox = Hive.box<ChatSession>('chat_sessions'); // Replace 'chats' with your actual box name

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Chats'),
        automaticallyImplyLeading: false, //Remove back button next to Active Chats
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<Box<ChatSession>>(
          valueListenable: _chatBox.listenable(),
          builder: (context, box, child) {
            final chatSessions = box.values.toList();
            if (chatSessions.isEmpty) {
              return const Center(child: Text('No Active Chats'));
            }
            return ListView.builder(
              itemCount: chatSessions.length,
              itemBuilder: (context, index) {
                final chatSession = chatSessions[index];
                // Display chat session details (e.g., participants, last message)
                return ListTile(
                  title: Text('Chat with ${chatSession.studentId}'),
                  subtitle: Text(chatSession.messages.last.encryptedContent),
                  onTap: () => // Handle chat session tap (e.g., navigate to chat details)
                  print('Navigate to chat details for ${chatSession.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}