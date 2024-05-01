class ChatSessionController {
  final _hiveService = HiveService(); // Instance of the HiveService

  Future<void> saveChatSession(ChatSession session) async {
    await _hiveService.saveChatSession(session);
  }

  Future<ChatSession?> getChatSession() async {
    return await _hiveService.getChatSession();
  }
}
