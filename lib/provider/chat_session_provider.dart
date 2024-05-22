import 'package:anon_cast/models/chat_session.dart';
import 'package:flutter/material.dart';

class ChatSessionProvider extends ChangeNotifier {
  ChatSession? _chatSession;

  ChatSession? get chatSession => _chatSession;

  void setChatSession(ChatSession chatSession) {
    _chatSession = chatSession;
    notifyListeners(); // Notify listeners when user changes
  }
}