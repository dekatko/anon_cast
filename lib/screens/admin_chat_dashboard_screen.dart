import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';

import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activeChatsTitle),
        automaticallyImplyLeading: false, //Remove back button next to Active Chats
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<Box<ChatSession>>(
          valueListenable: _chatBox.listenable(),
          builder: (context, box, child) {
            final chatSessions = box.values.toList();
            if (chatSessions.isEmpty) {
              return Center(child: Text(l10n.noActiveChats));
            }
            return ListView.builder(
              itemCount: chatSessions.length,
              itemBuilder: (context, index) {
                final chatSession = chatSessions[index];
                final lastMessage = chatSession.messages.isNotEmpty ? chatSession.messages.last : null;
                final truncatedMessage = lastMessage?.encryptedContent.split(' ').take(12).join(' '); // Truncate message to 12 words

                return Card(
                  child: ListTile(
                    title: Text(l10n.chatWithStudent(chatSession.studentId)),
                    subtitle: Text('$truncatedMessage...'),
                    onTap: () => // Handle chat session tap (e.g., navigate to chat details)
                    print('Navigate to chat details for ${chatSession.id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}