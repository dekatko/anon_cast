/// Returned by [AccessCodeService.redeemAccessCode] after a student successfully
/// redeems an access code. Contains the conversation id and metadata so the app
/// can open the E2E-encrypted conversation (key is already stored locally).
class ConversationData {
  const ConversationData({
    required this.conversationId,
    required this.organizationId,
    this.adminUserId,
    this.expiresAt,
  });

  /// Conversation ID to use with [MessageService] and UI.
  final String conversationId;
  /// Organization the conversation belongs to.
  final String organizationId;
  /// Admin who created the code (for display or routing).
  final String? adminUserId;
  /// When the access code expired (informational).
  final DateTime? expiresAt;
}
