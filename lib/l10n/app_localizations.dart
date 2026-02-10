import 'package:flutter/material.dart';

/// German-localization-ready strings for the admin dashboard.
/// Add more locales by checking [locale] and returning the right string.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('de'),
  ];

  // ——— Admin dashboard ———
  String get adminDashboardTitle =>
      _localizedValues[locale.languageCode]?['adminDashboardTitle'] ?? 'Messages';

  String get unreadBadge => _localizedValues[locale.languageCode]?['unreadBadge'] ?? 'Unread';

  String get filterByStatus =>
      _localizedValues[locale.languageCode]?['filterByStatus'] ?? 'Status';

  String get filterAll => _localizedValues[locale.languageCode]?['filterAll'] ?? 'All';

  String get filterUnread => _localizedValues[locale.languageCode]?['filterUnread'] ?? 'Unread';

  String get filterRead => _localizedValues[locale.languageCode]?['filterRead'] ?? 'Read';

  String get filterResolved =>
      _localizedValues[locale.languageCode]?['filterResolved'] ?? 'Resolved';

  String get searchHint =>
      _localizedValues[locale.languageCode]?['searchHint'] ?? 'Search messages…';

  String get filterByDate =>
      _localizedValues[locale.languageCode]?['filterByDate'] ?? 'Date';

  String get emptyTitle =>
      _localizedValues[locale.languageCode]?['emptyTitle'] ?? 'No messages';

  String get emptySubtitle =>
      _localizedValues[locale.languageCode]?['emptySubtitle'] ??
      'Anonymous messages will appear here when students reach out.';

  String get pullToRefresh =>
      _localizedValues[locale.languageCode]?['pullToRefresh'] ?? 'Pull to refresh';

  String get errorLoading =>
      _localizedValues[locale.languageCode]?['errorLoading'] ?? 'Error loading messages';

  String get retry => _localizedValues[locale.languageCode]?['retry'] ?? 'Retry';

  String get anonymousSender =>
      _localizedValues[locale.languageCode]?['anonymousSender'] ?? 'Anonymous';

  String get messageDetailTitle =>
      _localizedValues[locale.languageCode]?['messageDetailTitle'] ?? 'Message';

  String get reply => _localizedValues[locale.languageCode]?['reply'] ?? 'Reply';

  String get markRead => _localizedValues[locale.languageCode]?['markRead'] ?? 'Mark read';

  String get markResolved =>
      _localizedValues[locale.languageCode]?['markResolved'] ?? 'Mark resolved';

  // ——— Message thread ———
  String get messageThreadTitle =>
      _localizedValues[locale.languageCode]?['messageThreadTitle'] ?? 'Conversation';

  String get typeMessageHint =>
      _localizedValues[locale.languageCode]?['typeMessageHint'] ?? 'Type a message…';

  String get send => _localizedValues[locale.languageCode]?['send'] ?? 'Send';

  String get characterCount =>
      _localizedValues[locale.languageCode]?['characterCount'] ?? 'Characters';

  String get encryptionActive =>
      _localizedValues[locale.languageCode]?['encryptionActive'] ?? 'Encrypted';

  String get anonymousTyping =>
      _localizedValues[locale.languageCode]?['anonymousTyping'] ?? 'Anonymous is typing…';

  String get adminTyping =>
      _localizedValues[locale.languageCode]?['adminTyping'] ?? 'Counselor is typing…';

  String get readStatusRead =>
      _localizedValues[locale.languageCode]?['readStatusRead'] ?? 'Read';

  String get readStatusDelivered =>
      _localizedValues[locale.languageCode]?['readStatusDelivered'] ?? 'Delivered';

  String get messageFromAnonymous =>
      _localizedValues[locale.languageCode]?['messageFromAnonymous'] ?? 'Message from anonymous user';

  String get messageFromYou =>
      _localizedValues[locale.languageCode]?['messageFromYou'] ?? 'Your message';

  String get threadErrorSend =>
      _localizedValues[locale.languageCode]?['threadErrorSend'] ?? 'Failed to send message';

  String get statusSending =>
      _localizedValues[locale.languageCode]?['statusSending'] ?? 'Sending…';
  String get statusFailed =>
      _localizedValues[locale.languageCode]?['statusFailed'] ?? 'Failed to send';
  String get statusSent =>
      _localizedValues[locale.languageCode]?['statusSent'] ?? 'Sent';
  String get statusSyncing =>
      _localizedValues[locale.languageCode]?['statusSyncing'] ?? 'Syncing…';
  String get encryptionTooltip =>
      _localizedValues[locale.languageCode]?['encryptionTooltip'] ?? 'End-to-end encrypted';
  String get offlineBannerMessage =>
      _localizedValues[locale.languageCode]?['offlineBannerMessage'] ?? 'Offline – messages will send when connected';
  String get messagesWaitingToSend => _localizedValues[locale.languageCode]?['messagesWaitingToSend'] ??
      'messages waiting to send';

  String get securityStatus => _localizedValues[locale.languageCode]?['securityStatus'] ?? 'Security Status';
  String get securityAllPassed => _localizedValues[locale.languageCode]?['securityAllPassed'] ?? 'All checks passed';
  String get securitySomeFailed => _localizedValues[locale.languageCode]?['securitySomeFailed'] ?? 'Some checks failed';
  String get viewDetails => _localizedValues[locale.languageCode]?['viewDetails'] ?? 'View Details';
  String get messagesEncrypted => _localizedValues[locale.languageCode]?['messagesEncrypted'] ?? 'Messages Encrypted';
  String get keysStoredLocally => _localizedValues[locale.languageCode]?['keysStoredLocally'] ?? 'Keys Stored Locally';
  String get noDataLeaks => _localizedValues[locale.languageCode]?['noDataLeaks'] ?? 'No Data Leaks';
  String get rotationDue => _localizedValues[locale.languageCode]?['rotationDue'] ?? 'Rotation due';
  String keyRotatedDaysAgo(int days) =>
      _localizedValues[locale.languageCode]?['keyRotatedDaysAgo']?.replaceAll('{days}', '$days') ?? 'Key rotated $days days ago';
  String get noMessagesYet => _localizedValues[locale.languageCode]?['noMessagesYet'] ?? 'No messages yet';
  String get generateAccessCode => _localizedValues[locale.languageCode]?['generateAccessCode'] ?? 'Generate Access Code';
  String get expiryDaysLabel => _localizedValues[locale.languageCode]?['expiryDaysLabel'] ?? 'Expiry (days)';
  String get accessCodeGenerated => _localizedValues[locale.languageCode]?['accessCodeGenerated'] ?? 'Access Code Generated';
  String get expiresLabel => _localizedValues[locale.languageCode]?['expiresLabel'] ?? 'Expires';
  String get shareLabel => _localizedValues[locale.languageCode]?['shareLabel'] ?? 'Share';
  String get settingsLabel => _localizedValues[locale.languageCode]?['settingsLabel'] ?? 'Settings';
  String get conversationsLabel => _localizedValues[locale.languageCode]?['conversationsLabel'] ?? 'Conversations';

  // ——— Settings (privacy, keys, security) ———
  String get clearAllLocalData => _localizedValues[locale.languageCode]?['clearAllLocalData'] ?? 'Clear All Local Data';
  String get clearAllLocalDataSubtitle => _localizedValues[locale.languageCode]?['clearAllLocalDataSubtitle'] ?? 'Remove all messages and keys from this device';
  String get autoClearOnLogout => _localizedValues[locale.languageCode]?['autoClearOnLogout'] ?? 'Auto-clear on Logout';
  String get autoClearOnLogoutSubtitle => _localizedValues[locale.languageCode]?['autoClearOnLogoutSubtitle'] ?? 'Automatically delete data when logging out';
  String get exportEncryptionKeys => _localizedValues[locale.languageCode]?['exportEncryptionKeys'] ?? 'Export Encryption Keys';
  String get exportEncryptionKeysSubtitle => _localizedValues[locale.languageCode]?['exportEncryptionKeysSubtitle'] ?? 'Backup keys to transfer to another device';
  String get importEncryptionKeys => _localizedValues[locale.languageCode]?['importEncryptionKeys'] ?? 'Import Encryption Keys';
  String get importEncryptionKeysSubtitle => _localizedValues[locale.languageCode]?['importEncryptionKeysSubtitle'] ?? 'Restore keys from backup file';
  String get runSecurityAudit => _localizedValues[locale.languageCode]?['runSecurityAudit'] ?? 'Run Security Audit';
  String get runSecurityAuditSubtitle => _localizedValues[locale.languageCode]?['runSecurityAuditSubtitle'] ?? 'Verify encryption is working correctly';
  String get forceKeyRotation => _localizedValues[locale.languageCode]?['forceKeyRotation'] ?? 'Force Key Rotation';
  String get forceKeyRotationSubtitle => _localizedValues[locale.languageCode]?['forceKeyRotationSubtitle'] ?? 'Rotate all conversation keys now';
  String get protectYourKeys => _localizedValues[locale.languageCode]?['protectYourKeys'] ?? 'Protect Your Keys';
  String get protectYourKeysMessage => _localizedValues[locale.languageCode]?['protectYourKeysMessage'] ?? 'Enter a password to encrypt your key backup';
  String get enterBackupPassword => _localizedValues[locale.languageCode]?['enterBackupPassword'] ?? 'Enter Backup Password';
  String get enterBackupPasswordMessage => _localizedValues[locale.languageCode]?['enterBackupPasswordMessage'] ?? 'Enter the password you used when creating this backup';
  String get exportingKeys => _localizedValues[locale.languageCode]?['exportingKeys'] ?? 'Exporting keys…';
  String get importingKeys => _localizedValues[locale.languageCode]?['importingKeys'] ?? 'Importing keys…';
  String get keysExportedTo => _localizedValues[locale.languageCode]?['keysExportedTo'] ?? 'Keys exported to: %s';
  String get keepBackupSafe => _localizedValues[locale.languageCode]?['keepBackupSafe'] ?? 'Keep Your Backup Safe';
  String get keepBackupSafeMessage => _localizedValues[locale.languageCode]?['keepBackupSafeMessage'] ?? 'Store this file securely. Anyone with this file and your password can decrypt your messages.';
  String get iUnderstand => _localizedValues[locale.languageCode]?['iUnderstand'] ?? 'I Understand';
  String get importSuccessful => _localizedValues[locale.languageCode]?['importSuccessful'] ?? 'Import Successful';
  String get importSuccessfulMessage => _localizedValues[locale.languageCode]?['importSuccessfulMessage'] ?? 'Imported %s encryption keys. You can now access your conversations.';
  String get goToDashboard => _localizedValues[locale.languageCode]?['goToDashboard'] ?? 'Go to Dashboard';
  String get clearAllDataConfirmTitle => _localizedValues[locale.languageCode]?['clearAllDataConfirmTitle'] ?? 'Clear All Local Data?';
  String get clearAllDataConfirmMessage => _localizedValues[locale.languageCode]?['clearAllDataConfirmMessage'] ?? 'This will permanently delete:\n• All messages stored on this device\n• All encryption keys\n• All conversation history\n\nThis action cannot be undone. Messages in the cloud (encrypted) will remain.';
  String get clearAllDataButton => _localizedValues[locale.languageCode]?['clearAllDataButton'] ?? 'Clear All Data';
  String get allLocalDataCleared => _localizedValues[locale.languageCode]?['allLocalDataCleared'] ?? 'All local data cleared';
  String get continueLabel => _localizedValues[locale.languageCode]?['continueLabel'] ?? 'Continue';
  String get passwordLabel => _localizedValues[locale.languageCode]?['passwordLabel'] ?? 'Password';
  String get exportFailed => _localizedValues[locale.languageCode]?['exportFailed'] ?? 'Export failed: %s';
  String get importFailed => _localizedValues[locale.languageCode]?['importFailed'] ?? 'Import failed: %s';
  String get importFailedHint => _localizedValues[locale.languageCode]?['importFailedHint'] ?? 'Make sure you entered the correct password.';
  String get securityCheckFailed => _localizedValues[locale.languageCode]?['securityCheckFailed'] ?? 'Security check failed';
  String get rotationComplete => _localizedValues[locale.languageCode]?['rotationComplete'] ?? 'Rotation complete: %s keys rotated.';
  String get rotationFailed => _localizedValues[locale.languageCode]?['rotationFailed'] ?? 'Rotation failed: %s';
  String get privacySectionTitle => _localizedValues[locale.languageCode]?['privacySectionTitle'] ?? 'Privacy';
  String get keyManagementSectionTitle => _localizedValues[locale.languageCode]?['keyManagementSectionTitle'] ?? 'Key Management';
  String get securitySectionTitle => _localizedValues[locale.languageCode]?['securitySectionTitle'] ?? 'Security';

  // ——— User management (access codes) ———
  String get userManagementTitle =>
      _localizedValues[locale.languageCode]?['userManagementTitle'] ?? 'Access codes';

  String get generateNewCode =>
      _localizedValues[locale.languageCode]?['generateNewCode'] ?? 'Generate new code';

  String get expiryTime =>
      _localizedValues[locale.languageCode]?['expiryTime'] ?? 'Expiry';

  String get singleUse =>
      _localizedValues[locale.languageCode]?['singleUse'] ?? 'Single use';

  String get copyCode =>
      _localizedValues[locale.languageCode]?['copyCode'] ?? 'Copy code';

  String get codeCopied =>
      _localizedValues[locale.languageCode]?['codeCopied'] ?? 'Code copied';

  String get revokeCode =>
      _localizedValues[locale.languageCode]?['revokeCode'] ?? 'Revoke';

  String get deleteCode =>
      _localizedValues[locale.languageCode]?['deleteCode'] ?? 'Delete';

  String get revokeConfirm =>
      _localizedValues[locale.languageCode]?['revokeConfirm'] ?? 'Revoke this code? It cannot be used again.';

  String get deleteConfirm =>
      _localizedValues[locale.languageCode]?['deleteConfirm'] ?? 'Permanently delete this code?';

  String get cancel =>
      _localizedValues[locale.languageCode]?['cancel'] ?? 'Cancel';

  String get confirm =>
      _localizedValues[locale.languageCode]?['confirm'] ?? 'Confirm';

  String get activeUsers =>
      _localizedValues[locale.languageCode]?['activeUsers'] ?? 'Active users';

  String get totalAnonymousUsers =>
      _localizedValues[locale.languageCode]?['totalAnonymousUsers'] ?? 'Anonymous users (total)';

  String get messagesLast24h =>
      _localizedValues[locale.languageCode]?['messagesLast24h'] ?? 'Messages (24h)';

  String get messagesLast7d =>
      _localizedValues[locale.languageCode]?['messagesLast7d'] ?? 'Messages (7d)';

  String get exportCsv =>
      _localizedValues[locale.languageCode]?['exportCsv'] ?? 'Export to CSV';

  String get searchCodes =>
      _localizedValues[locale.languageCode]?['searchCodes'] ?? 'Search codes…';

  String get codeStatusActive =>
      _localizedValues[locale.languageCode]?['codeStatusActive'] ?? 'Active';

  String get codeStatusUsed =>
      _localizedValues[locale.languageCode]?['codeStatusUsed'] ?? 'Used';

  String get codeStatusExpired =>
      _localizedValues[locale.languageCode]?['codeStatusExpired'] ?? 'Expired';

  String get codeStatusRevoked =>
      _localizedValues[locale.languageCode]?['codeStatusRevoked'] ?? 'Revoked';

  String get showQr =>
      _localizedValues[locale.languageCode]?['showQr'] ?? 'Show QR code';

  String get days => _localizedValues[locale.languageCode]?['days'] ?? 'days';

  String get noCodes =>
      _localizedValues[locale.languageCode]?['noCodes'] ?? 'No codes yet. Generate one to get started.';

  String get errorLoadingCodes =>
      _localizedValues[locale.languageCode]?['errorLoadingCodes'] ?? 'Error loading codes';

  String get errorGenerate =>
      _localizedValues[locale.languageCode]?['errorGenerate'] ?? 'Failed to generate code';

  // ——— Auth / Login ———
  String get loginTitle => _localizedValues[locale.languageCode]?['loginTitle'] ?? 'Elly';
  String get tabAdmin => _localizedValues[locale.languageCode]?['tabAdmin'] ?? 'Counselor';
  String get tabAnonymous => _localizedValues[locale.languageCode]?['tabAnonymous'] ?? 'Anonymous';
  String get email => _localizedValues[locale.languageCode]?['email'] ?? 'Email';
  String get password => _localizedValues[locale.languageCode]?['password'] ?? 'Password';
  String get accessCode => _localizedValues[locale.languageCode]?['accessCode'] ?? 'Access code';
  String get login => _localizedValues[locale.languageCode]?['login'] ?? 'Log in';
  String get forgotPassword => _localizedValues[locale.languageCode]?['forgotPassword'] ?? 'Forgot password?';
  String get continueToChat => _localizedValues[locale.languageCode]?['continueToChat'] ?? 'Continue';
  String get register => _localizedValues[locale.languageCode]?['register'] ?? 'Register';
  String get administratorLogin => _localizedValues[locale.languageCode]?['administratorLogin'] ?? 'Counselor login';
  String get administratorRegister => _localizedValues[locale.languageCode]?['administratorRegister'] ?? 'Counselor registration';

  String get administratorDashboardTitle => _localizedValues[locale.languageCode]?['administratorDashboardTitle'] ?? 'Administrator Dashboard';
  String get navMessages => _localizedValues[locale.languageCode]?['navMessages'] ?? 'Messages';
  String get navUsers => _localizedValues[locale.languageCode]?['navUsers'] ?? 'Users';
  String get navRotation => _localizedValues[locale.languageCode]?['navRotation'] ?? 'Rotation';
  String get keyRotationTitle => _localizedValues[locale.languageCode]?['keyRotationTitle'] ?? 'Key Rotation';
  String get noConversationsYet => _localizedValues[locale.languageCode]?['noConversationsYet'] ?? 'No conversations yet.';
  String get checkAndRotateE2ENow => _localizedValues[locale.languageCode]?['checkAndRotateE2ENow'] ?? 'Check & rotate E2E keys now';
  String get rotateButton => _localizedValues[locale.languageCode]?['rotateButton'] ?? 'Rotate';
  String get rotatingLabel => _localizedValues[locale.languageCode]?['rotatingLabel'] ?? 'Rotating…';
  String get checkAndRotateNow => _localizedValues[locale.languageCode]?['checkAndRotateNow'] ?? 'Check & rotate now';
  String get systemSettingsTitle => _localizedValues[locale.languageCode]?['systemSettingsTitle'] ?? 'System Settings';
  String get exportKeysComingSoon => _localizedValues[locale.languageCode]?['exportKeysComingSoon'] ?? 'Export keys: enter password in dialog (coming soon)';
  String get importKeysComingSoon => _localizedValues[locale.languageCode]?['importKeysComingSoon'] ?? 'Import keys: upload file and enter password (coming soon)';
  String get auditFailed => _localizedValues[locale.languageCode]?['auditFailed'] ?? 'Audit failed: %s';
  String get wifiDirect => _localizedValues[locale.languageCode]?['wifiDirect'] ?? 'Wi-Fi Direct';
  String get externalServer => _localizedValues[locale.languageCode]?['externalServer'] ?? 'External Server';
  String get localServer => _localizedValues[locale.languageCode]?['localServer'] ?? 'Local Server';
  String get viewLastReport => _localizedValues[locale.languageCode]?['viewLastReport'] ?? 'View last report';
  String get runAuditTooltip => _localizedValues[locale.languageCode]?['runAuditTooltip'] ?? 'Run audit';
  String get exportConversationKeys => _localizedValues[locale.languageCode]?['exportConversationKeys'] ?? 'Export conversation keys';
  String get exportConversationKeysSubtitle => _localizedValues[locale.languageCode]?['exportConversationKeysSubtitle'] ?? 'Save encrypted keys to a file for use on another device';
  String get importConversationKeys => _localizedValues[locale.languageCode]?['importConversationKeys'] ?? 'Import conversation keys';
  String get importConversationKeysSubtitle => _localizedValues[locale.languageCode]?['importConversationKeysSubtitle'] ?? 'Restore keys from a file (e.g. after switching device)';
  String get securityAuditTitle => _localizedValues[locale.languageCode]?['securityAuditTitle'] ?? 'Security Audit';
  String get runAgain => _localizedValues[locale.languageCode]?['runAgain'] ?? 'Run again';
  String get chatRoomTitle => _localizedValues[locale.languageCode]?['chatRoomTitle'] ?? 'Chat Room';
  String get errorLoadingSession => _localizedValues[locale.languageCode]?['errorLoadingSession'] ?? 'Error loading session';
  String get activeChatsTitle => _localizedValues[locale.languageCode]?['activeChatsTitle'] ?? 'Active Chats';
  String get noActiveChats => _localizedValues[locale.languageCode]?['noActiveChats'] ?? 'No Active Chats';
  String chatWithStudent(String studentId) => (_localizedValues[locale.languageCode]?['chatWithStudent'] ?? 'Chat with %s').replaceAll('%s', studentId);
  String get filterToday => _localizedValues[locale.languageCode]?['filterToday'] ?? 'Today';
  String get filterYesterday => _localizedValues[locale.languageCode]?['filterYesterday'] ?? 'Yesterday';
  String get filterThisWeek => _localizedValues[locale.languageCode]?['filterThisWeek'] ?? 'This week';
  String get filterClear => _localizedValues[locale.languageCode]?['filterClear'] ?? 'Clear';
  String get noConversationId => _localizedValues[locale.languageCode]?['noConversationId'] ?? 'No conversation ID';
  String get nameLabel => _localizedValues[locale.languageCode]?['nameLabel'] ?? 'Name';
  String get accessCodeHint => _localizedValues[locale.languageCode]?['accessCodeHint'] ?? 'XXXXXX';
  String get adminSelectionTitle => _localizedValues[locale.languageCode]?['adminSelectionTitle'] ?? 'Admin Selection';
  String get connectionSettingsTitle => _localizedValues[locale.languageCode]?['connectionSettingsTitle'] ?? 'Connection Settings';
  String get securityAuditSectionTitle => _localizedValues[locale.languageCode]?['securityAuditSectionTitle'] ?? 'Security audit';
  String get conversationKeysSectionTitle => _localizedValues[locale.languageCode]?['conversationKeysSectionTitle'] ?? 'Conversation keys (multi-device)';
  String get verifyEncryptionAndKeyStorage => _localizedValues[locale.languageCode]?['verifyEncryptionAndKeyStorage'] ?? 'Verify encryption and key storage';

  // ——— Statistics / reporting ———
  String get totalMessages => _localizedValues[locale.languageCode]?['totalMessages'] ?? 'Total messages';
  String get activeConversations => _localizedValues[locale.languageCode]?['activeConversations'] ?? 'Active conversations';
  String get unreadMessages => _localizedValues[locale.languageCode]?['unreadMessages'] ?? 'Unread';
  String get averagePerDay => _localizedValues[locale.languageCode]?['averagePerDay'] ?? 'Ø per day';
  String get messageHistory => _localizedValues[locale.languageCode]?['messageHistory'] ?? 'Message history';
  String get noDataAvailable => _localizedValues[locale.languageCode]?['noDataAvailable'] ?? 'No data available';
  String get averageFirstResponse => _localizedValues[locale.languageCode]?['averageFirstResponse'] ?? 'First response time';
  String get averageResponseTime => _localizedValues[locale.languageCode]?['averageResponseTime'] ?? 'Average response time';
  String get responseRate => _localizedValues[locale.languageCode]?['responseRate'] ?? 'Response rate';

  String get responseTimes => _localizedValues[locale.languageCode]?['responseTimes'] ?? 'Response times';

  String get dateRangeLabel => _localizedValues[locale.languageCode]?['dateRangeLabel'] ?? 'Period:';
  String get exportPdfTooltip => _localizedValues[locale.languageCode]?['exportPdfTooltip'] ?? 'Export as PDF';
  String get exportSuccess => _localizedValues[locale.languageCode]?['exportSuccess'] ?? 'Report exported';
  String get exportError => _localizedValues[locale.languageCode]?['exportError'] ?? 'Export failed';
  String get lastUpdated => _localizedValues[locale.languageCode]?['lastUpdated'] ?? 'Last updated';
  String lastUpdatedMinutesAgo(int minutes) =>
      (_localizedValues[locale.languageCode]?['lastUpdatedMinutesAgo'] ?? 'Last updated: %s min ago').replaceFirst('%s', '$minutes');
  String get forceRefresh => _localizedValues[locale.languageCode]?['forceRefresh'] ?? 'Force refresh';
  String get vsLastWeek => _localizedValues[locale.languageCode]?['vsLastWeek'] ?? 'vs. last week';
  String get vsLastMonth => _localizedValues[locale.languageCode]?['vsLastMonth'] ?? 'vs. last month';
  String get vsPreviousPeriod => _localizedValues[locale.languageCode]?['vsPreviousPeriod'] ?? 'vs. previous period';
  String get trendUp => _localizedValues[locale.languageCode]?['trendUp'] ?? 'Up';
  String get trendDown => _localizedValues[locale.languageCode]?['trendDown'] ?? 'Down';
  String get trendStable => _localizedValues[locale.languageCode]?['trendStable'] ?? 'Stable';
  String get last7Days => _localizedValues[locale.languageCode]?['last7Days'] ?? 'Last 7 days';
  String get last30Days => _localizedValues[locale.languageCode]?['last30Days'] ?? 'Last 30 days';
  String get thisMonth => _localizedValues[locale.languageCode]?['thisMonth'] ?? 'This month';
  String get adminPerformance => _localizedValues[locale.languageCode]?['adminPerformance'] ?? 'Admin performance';
  String get leaderboard => _localizedValues[locale.languageCode]?['leaderboard'] ?? 'Leaderboard';
  String get topPerformer => _localizedValues[locale.languageCode]?['topPerformer'] ?? 'Top performer';
  String get conversationsHandled => _localizedValues[locale.languageCode]?['conversationsHandled'] ?? 'Conversations handled';
  String get messagesPerDay => _localizedValues[locale.languageCode]?['messagesPerDay'] ?? 'Messages/day';
  String get rank => _localizedValues[locale.languageCode]?['rank'] ?? 'Rank';
  String get messagesSent => _localizedValues[locale.languageCode]?['messagesSent'] ?? 'Messages sent';

  /// Resolve auth error message key to localized string.
  String authErrorMessage(String messageKey) {
    return _localizedValues[locale.languageCode]?[messageKey] ??
        _localizedValues['en']?[messageKey] ??
        messageKey;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'adminDashboardTitle': 'Messages',
      'unreadBadge': 'Unread',
      'filterByStatus': 'Status',
      'filterAll': 'All',
      'filterUnread': 'Unread',
      'filterRead': 'Read',
      'filterResolved': 'Resolved',
      'searchHint': 'Search messages…',
      'filterByDate': 'Date',
      'emptyTitle': 'No messages',
      'emptySubtitle':
          'Anonymous messages will appear here when students reach out.',
      'pullToRefresh': 'Pull to refresh',
      'errorLoading': 'Error loading messages',
      'retry': 'Retry',
      'anonymousSender': 'Anonymous',
      'messageDetailTitle': 'Message',
      'reply': 'Reply',
      'markRead': 'Mark read',
      'markResolved': 'Mark resolved',
      'messageThreadTitle': 'Conversation',
      'typeMessageHint': 'Type a message…',
      'send': 'Send',
      'characterCount': 'Characters',
      'encryptionActive': 'Encrypted',
      'anonymousTyping': 'Anonymous is typing…',
      'adminTyping': 'Counselor is typing…',
      'readStatusRead': 'Read',
      'readStatusDelivered': 'Delivered',
      'messageFromAnonymous': 'Message from anonymous user',
      'messageFromYou': 'Your message',
      'threadErrorSend': 'Failed to send message',
      'statusSending': 'Sending…',
      'statusFailed': 'Failed to send',
      'statusSent': 'Sent',
      'statusSyncing': 'Syncing…',
      'encryptionTooltip': 'End-to-end encrypted',
      'offlineBannerMessage': 'Offline – messages will send when connected',
      'messagesWaitingToSend': 'messages waiting to send',
      'securityStatus': 'Security Status',
      'securityAllPassed': 'All checks passed',
      'securitySomeFailed': 'Some checks failed',
      'viewDetails': 'View Details',
      'messagesEncrypted': 'Messages Encrypted',
      'keysStoredLocally': 'Keys Stored Locally',
      'noDataLeaks': 'No Data Leaks',
      'rotationDue': 'Rotation due',
      'keyRotatedDaysAgo': 'Key rotated {days} days ago',
      'noMessagesYet': 'No messages yet',
      'generateAccessCode': 'Generate Access Code',
      'expiryDaysLabel': 'Expiry (days)',
      'accessCodeGenerated': 'Access Code Generated',
      'expiresLabel': 'Expires',
      'shareLabel': 'Share',
      'settingsLabel': 'Settings',
      'conversationsLabel': 'Conversations',
      'clearAllLocalData': 'Clear All Local Data',
      'clearAllLocalDataSubtitle': 'Remove all messages and keys from this device',
      'autoClearOnLogout': 'Auto-clear on Logout',
      'autoClearOnLogoutSubtitle': 'Automatically delete data when logging out',
      'exportEncryptionKeys': 'Export Encryption Keys',
      'exportEncryptionKeysSubtitle': 'Backup keys to transfer to another device',
      'importEncryptionKeys': 'Import Encryption Keys',
      'importEncryptionKeysSubtitle': 'Restore keys from backup file',
      'runSecurityAudit': 'Run Security Audit',
      'runSecurityAuditSubtitle': 'Verify encryption is working correctly',
      'forceKeyRotation': 'Force Key Rotation',
      'forceKeyRotationSubtitle': 'Rotate all conversation keys now',
      'protectYourKeys': 'Protect Your Keys',
      'protectYourKeysMessage': 'Enter a password to encrypt your key backup',
      'enterBackupPassword': 'Enter Backup Password',
      'enterBackupPasswordMessage': 'Enter the password you used when creating this backup',
      'exportingKeys': 'Exporting keys…',
      'importingKeys': 'Importing keys…',
      'keysExportedTo': 'Keys exported to: %s',
      'keepBackupSafe': 'Keep Your Backup Safe',
      'keepBackupSafeMessage': 'Store this file securely. Anyone with this file and your password can decrypt your messages.',
      'iUnderstand': 'I Understand',
      'importSuccessful': 'Import Successful',
      'importSuccessfulMessage': 'Imported %s encryption keys. You can now access your conversations.',
      'goToDashboard': 'Go to Dashboard',
      'clearAllDataConfirmTitle': 'Clear All Local Data?',
      'clearAllDataConfirmMessage': 'This will permanently delete:\n• All messages stored on this device\n• All encryption keys\n• All conversation history\n\nThis action cannot be undone. Messages in the cloud (encrypted) will remain.',
      'clearAllDataButton': 'Clear All Data',
      'allLocalDataCleared': 'All local data cleared',
      'continueLabel': 'Continue',
      'passwordLabel': 'Password',
      'exportFailed': 'Export failed: %s',
      'importFailed': 'Import failed: %s',
      'importFailedHint': 'Make sure you entered the correct password.',
      'securityCheckFailed': 'Security check failed',
      'rotationComplete': 'Rotation complete: %s keys rotated.',
      'rotationFailed': 'Rotation failed: %s',
      'privacySectionTitle': 'Privacy',
      'keyManagementSectionTitle': 'Key Management',
      'securitySectionTitle': 'Security',
      'userManagementTitle': 'Access codes',
      'generateNewCode': 'Generate new code',
      'expiryTime': 'Expiry',
      'singleUse': 'Single use',
      'copyCode': 'Copy code',
      'codeCopied': 'Code copied',
      'revokeCode': 'Revoke',
      'deleteCode': 'Delete',
      'revokeConfirm': 'Revoke this code? It cannot be used again.',
      'deleteConfirm': 'Permanently delete this code?',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'activeUsers': 'Active users',
      'totalAnonymousUsers': 'Anonymous users (total)',
      'messagesLast24h': 'Messages (24h)',
      'messagesLast7d': 'Messages (7d)',
      'exportCsv': 'Export to CSV',
      'searchCodes': 'Search codes…',
      'codeStatusActive': 'Active',
      'codeStatusUsed': 'Used',
      'codeStatusExpired': 'Expired',
      'codeStatusRevoked': 'Revoked',
      'showQr': 'Show QR code',
      'days': 'days',
      'noCodes': 'No codes yet. Generate one to get started.',
      'errorLoadingCodes': 'Error loading codes',
      'errorGenerate': 'Failed to generate code',
      'loginTitle': 'Elly',
      'tabAdmin': 'Counselor',
      'tabAnonymous': 'Anonymous',
      'email': 'Email',
      'password': 'Password',
      'accessCode': 'Access code',
      'login': 'Log in',
      'forgotPassword': 'Forgot password?',
      'continueToChat': 'Continue',
      'register': 'Register',
      'administratorLogin': 'Counselor login',
      'administratorRegister': 'Counselor registration',
      'administratorDashboardTitle': 'Administrator Dashboard',
      'navMessages': 'Messages',
      'navUsers': 'Users',
      'navRotation': 'Rotation',
      'keyRotationTitle': 'Key Rotation',
      'noConversationsYet': 'No conversations yet.',
      'checkAndRotateE2ENow': 'Check & rotate E2E keys now',
      'rotateButton': 'Rotate',
      'rotatingLabel': 'Rotating…',
      'checkAndRotateNow': 'Check & rotate now',
      'systemSettingsTitle': 'System Settings',
      'exportKeysComingSoon': 'Export keys: enter password in dialog (coming soon)',
      'importKeysComingSoon': 'Import keys: upload file and enter password (coming soon)',
      'auditFailed': 'Audit failed: %s',
      'wifiDirect': 'Wi-Fi Direct',
      'externalServer': 'External Server',
      'localServer': 'Local Server',
      'viewLastReport': 'View last report',
      'runAuditTooltip': 'Run audit',
      'exportConversationKeys': 'Export conversation keys',
      'exportConversationKeysSubtitle': 'Save encrypted keys to a file for use on another device',
      'importConversationKeys': 'Import conversation keys',
      'importConversationKeysSubtitle': 'Restore keys from a file (e.g. after switching device)',
      'securityAuditTitle': 'Security Audit',
      'runAgain': 'Run again',
      'chatRoomTitle': 'Chat Room',
      'errorLoadingSession': 'Error loading session',
      'activeChatsTitle': 'Active Chats',
      'noActiveChats': 'No Active Chats',
      'chatWithStudent': 'Chat with %s',
      'filterToday': 'Today',
      'filterYesterday': 'Yesterday',
      'filterThisWeek': 'This week',
      'filterClear': 'Clear',
      'noConversationId': 'No conversation ID',
      'nameLabel': 'Name',
      'accessCodeHint': 'XXXXXX',
      'adminSelectionTitle': 'Admin Selection',
      'connectionSettingsTitle': 'Connection Settings',
      'securityAuditSectionTitle': 'Security audit',
      'conversationKeysSectionTitle': 'Conversation keys (multi-device)',
      'verifyEncryptionAndKeyStorage': 'Verify encryption and key storage',
      'totalMessages': 'Total messages',
      'activeConversations': 'Active conversations',
      'unreadMessages': 'Unread',
      'averagePerDay': 'Ø per day',
      'messageHistory': 'Message history',
      'noDataAvailable': 'No data available',
      'averageFirstResponse': 'First response time',
      'averageResponseTime': 'Average response time',
      'responseRate': 'Response rate',
      'responseTimes': 'Response times',
      'dateRangeLabel': 'Period:',
      'exportPdfTooltip': 'Export as PDF',
      'exportSuccess': 'Report exported',
      'exportError': 'Export failed',
      'lastUpdated': 'Last updated',
      'lastUpdatedMinutesAgo': 'Last updated: %s min ago',
      'forceRefresh': 'Force refresh',
      'vsLastWeek': 'vs. last week',
      'vsLastMonth': 'vs. last month',
      'vsPreviousPeriod': 'vs. previous period',
      'trendUp': 'Up',
      'trendDown': 'Down',
      'trendStable': 'Stable',
      'last7Days': 'Last 7 days',
      'last30Days': 'Last 30 days',
      'thisMonth': 'This month',
      'adminPerformance': 'Admin performance',
      'leaderboard': 'Leaderboard',
      'topPerformer': 'Top performer',
      'conversationsHandled': 'Conversations handled',
      'messagesPerDay': 'Messages/day',
      'rank': 'Rank',
      'messagesSent': 'Messages sent',
      'auth_error_email_required': 'Please enter your email.',
      'auth_error_password_required': 'Please enter your password.',
      'auth_error_code_required': 'Please enter your access code.',
      'auth_error_code_invalid': 'Invalid or unknown access code.',
      'auth_error_code_expired': 'This access code has expired.',
      'auth_error_code_used': 'This code has already been used.',
      'auth_error_code_revoked': 'This access code has been revoked.',
      'auth_error_user_not_found': 'No account found for this email.',
      'auth_error_wrong_password': 'Incorrect password.',
      'auth_error_user_disabled': 'This account has been disabled.',
      'auth_error_too_many_requests': 'Too many attempts. Please try again later.',
      'auth_error_anonymous_disabled': 'Anonymous access is not available.',
      'auth_error_unknown': 'Something went wrong. Please try again.',
    },
    'de': {
      'adminDashboardTitle': 'Nachrichten',
      'unreadBadge': 'Ungelesen',
      'filterByStatus': 'Status',
      'filterAll': 'Alle',
      'filterUnread': 'Ungelesen',
      'filterRead': 'Gelesen',
      'filterResolved': 'Erledigt',
      'searchHint': 'Nachrichten suchen…',
      'filterByDate': 'Datum',
      'emptyTitle': 'Keine Nachrichten',
      'emptySubtitle':
          'Anonyme Nachrichten erscheinen hier, wenn sich Schüler:innen melden.',
      'pullToRefresh': 'Zum Aktualisieren ziehen',
      'errorLoading': 'Fehler beim Laden der Nachrichten',
      'retry': 'Erneut versuchen',
      'anonymousSender': 'Anonym',
      'messageDetailTitle': 'Nachricht',
      'reply': 'Antworten',
      'markRead': 'Als gelesen markieren',
      'markResolved': 'Als erledigt markieren',
      'messageThreadTitle': 'Unterhaltung',
      'typeMessageHint': 'Nachricht eingeben…',
      'send': 'Senden',
      'characterCount': 'Zeichen',
      'encryptionActive': 'Verschlüsselt',
      'anonymousTyping': 'Anonym schreibt…',
      'adminTyping': 'Berater:in schreibt…',
      'readStatusRead': 'Gelesen',
      'readStatusDelivered': 'Zugestellt',
      'messageFromAnonymous': 'Nachricht von anonymem Nutzer',
      'messageFromYou': 'Deine Nachricht',
      'threadErrorSend': 'Nachricht konnte nicht gesendet werden',
      'statusSending': 'Wird gesendet…',
      'statusFailed': 'Senden fehlgeschlagen',
      'statusSent': 'Gesendet',
      'statusSyncing': 'Wird synchronisiert…',
      'encryptionTooltip': 'Ende-zu-Ende verschlüsselt',
      'offlineBannerMessage': 'Offline – Nachrichten werden bei Verbindung gesendet',
      'messagesWaitingToSend': 'Nachrichten warten auf Versand',
      'securityStatus': 'Sicherheitsstatus',
      'securityAllPassed': 'Alle Prüfungen bestanden',
      'securitySomeFailed': 'Einige Prüfungen fehlgeschlagen',
      'viewDetails': 'Details anzeigen',
      'messagesEncrypted': 'Nachrichten verschlüsselt',
      'keysStoredLocally': 'Schlüssel lokal gespeichert',
      'noDataLeaks': 'Keine Datenlecks',
      'rotationDue': 'Rotation fällig',
      'keyRotatedDaysAgo': 'Schlüssel vor {days} Tagen rotiert',
      'noMessagesYet': 'Noch keine Nachrichten',
      'generateAccessCode': 'Zugangscode erzeugen',
      'expiryDaysLabel': 'Gültigkeit (Tage)',
      'accessCodeGenerated': 'Zugangscode erzeugt',
      'expiresLabel': 'Läuft ab',
      'shareLabel': 'Teilen',
      'settingsLabel': 'Einstellungen',
      'conversationsLabel': 'Unterhaltungen',
      'clearAllLocalData': 'Alle lokalen Daten löschen',
      'clearAllLocalDataSubtitle': 'Alle Nachrichten und Schlüssel von diesem Gerät entfernen',
      'autoClearOnLogout': 'Beim Abmelden automatisch löschen',
      'autoClearOnLogoutSubtitle': 'Daten beim Abmelden automatisch löschen',
      'exportEncryptionKeys': 'Verschlüsselungsschlüssel exportieren',
      'exportEncryptionKeysSubtitle': 'Schlüssel sichern, um sie auf ein anderes Gerät zu übertragen',
      'importEncryptionKeys': 'Verschlüsselungsschlüssel importieren',
      'importEncryptionKeysSubtitle': 'Schlüssel aus Sicherungskopie wiederherstellen',
      'runSecurityAudit': 'Sicherheitsprüfung ausführen',
      'runSecurityAuditSubtitle': 'Prüfen, ob die Verschlüsselung korrekt funktioniert',
      'forceKeyRotation': 'Schlüsselrotation erzwingen',
      'forceKeyRotationSubtitle': 'Alle Konversationsschlüssel jetzt rotieren',
      'protectYourKeys': 'Schlüssel schützen',
      'protectYourKeysMessage': 'Geben Sie ein Passwort ein, um Ihren Schlüssel-Backup zu verschlüsseln',
      'enterBackupPassword': 'Backup-Passwort eingeben',
      'enterBackupPasswordMessage': 'Geben Sie das Passwort ein, das Sie bei der Erstellung dieses Backups verwendet haben',
      'exportingKeys': 'Schlüssel werden exportiert…',
      'importingKeys': 'Schlüssel werden importiert…',
      'keysExportedTo': 'Schlüssel exportiert nach: %s',
      'keepBackupSafe': 'Backup sicher aufbewahren',
      'keepBackupSafeMessage': 'Bewahren Sie diese Datei sicher auf. Jeder mit dieser Datei und Ihrem Passwort kann Ihre Nachrichten entschlüsseln.',
      'iUnderstand': 'Verstanden',
      'importSuccessful': 'Import erfolgreich',
      'importSuccessfulMessage': '%s Verschlüsselungsschlüssel importiert. Sie können jetzt auf Ihre Konversationen zugreifen.',
      'goToDashboard': 'Zum Dashboard',
      'clearAllDataConfirmTitle': 'Alle lokalen Daten löschen?',
      'clearAllDataConfirmMessage': 'Dies dauerhaft löschen:\n• Alle auf diesem Gerät gespeicherten Nachrichten\n• Alle Verschlüsselungsschlüssel\n• Den gesamten Konversationsverlauf\n\nDiese Aktion kann nicht rückgängig gemacht werden. Nachrichten in der Cloud (verschlüsselt) bleiben erhalten.',
      'clearAllDataButton': 'Alle Daten löschen',
      'allLocalDataCleared': 'Alle lokalen Daten gelöscht',
      'continueLabel': 'Weiter',
      'passwordLabel': 'Passwort',
      'exportFailed': 'Export fehlgeschlagen: %s',
      'importFailed': 'Import fehlgeschlagen: %s',
      'importFailedHint': 'Stellen Sie sicher, dass Sie das richtige Passwort eingegeben haben.',
      'securityCheckFailed': 'Sicherheitsprüfung fehlgeschlagen',
      'rotationComplete': 'Rotation abgeschlossen: %s Schlüssel rotiert.',
      'rotationFailed': 'Rotation fehlgeschlagen: %s',
      'privacySectionTitle': 'Datenschutz',
      'keyManagementSectionTitle': 'Schlüsselverwaltung',
      'securitySectionTitle': 'Sicherheit',
      'userManagementTitle': 'Zugangscodes',
      'generateNewCode': 'Neuen Code erzeugen',
      'expiryTime': 'Gültigkeit',
      'singleUse': 'Einmalige Nutzung',
      'copyCode': 'Code kopieren',
      'codeCopied': 'Code kopiert',
      'revokeCode': 'Widerrufen',
      'deleteCode': 'Löschen',
      'revokeConfirm': 'Diesen Code widerrufen? Er kann nicht mehr genutzt werden.',
      'deleteConfirm': 'Diesen Code endgültig löschen?',
      'cancel': 'Abbrechen',
      'confirm': 'Bestätigen',
      'activeUsers': 'Aktive Nutzer',
      'totalAnonymousUsers': 'Anonyme Nutzer (gesamt)',
      'messagesLast24h': 'Nachrichten (24h)',
      'messagesLast7d': 'Nachrichten (7d)',
      'exportCsv': 'Als CSV exportieren',
      'searchCodes': 'Codes suchen…',
      'codeStatusActive': 'Aktiv',
      'codeStatusUsed': 'Benutzt',
      'codeStatusExpired': 'Abgelaufen',
      'codeStatusRevoked': 'Widerrufen',
      'showQr': 'QR-Code anzeigen',
      'days': 'Tage',
      'noCodes': 'Noch keine Codes. Erzeuge einen zum Start.',
      'errorLoadingCodes': 'Fehler beim Laden der Codes',
      'errorGenerate': 'Code konnte nicht erzeugt werden',
      'loginTitle': 'Elly',
      'tabAdmin': 'Berater:in',
      'tabAnonymous': 'Anonym',
      'email': 'E-Mail',
      'password': 'Passwort',
      'accessCode': 'Zugangscode',
      'login': 'Anmelden',
      'forgotPassword': 'Passwort vergessen?',
      'continueToChat': 'Weiter',
      'register': 'Registrieren',
      'administratorLogin': 'Berater:in-Anmeldung',
      'administratorRegister': 'Berater:in-Registrierung',
      'administratorDashboardTitle': 'Administrator-Dashboard',
      'navMessages': 'Nachrichten',
      'navUsers': 'Nutzer',
      'navRotation': 'Rotation',
      'keyRotationTitle': 'Schlüsselrotation',
      'noConversationsYet': 'Noch keine Unterhaltungen.',
      'checkAndRotateE2ENow': 'E2E-Schlüssel jetzt prüfen & rotieren',
      'rotateButton': 'Rotieren',
      'rotatingLabel': 'Wird rotiert…',
      'checkAndRotateNow': 'Jetzt prüfen & rotieren',
      'systemSettingsTitle': 'Systemeinstellungen',
      'exportKeysComingSoon': 'Schlüssel exportieren: Passwort im Dialog eingeben (demnächst)',
      'importKeysComingSoon': 'Schlüssel importieren: Datei hochladen und Passwort eingeben (demnächst)',
      'auditFailed': 'Prüfung fehlgeschlagen: %s',
      'wifiDirect': 'WLAN Direct',
      'externalServer': 'Externer Server',
      'localServer': 'Lokaler Server',
      'viewLastReport': 'Letzten Bericht anzeigen',
      'runAuditTooltip': 'Prüfung ausführen',
      'exportConversationKeys': 'Konversationsschlüssel exportieren',
      'exportConversationKeysSubtitle': 'Verschlüsselte Schlüssel in Datei speichern für anderes Gerät',
      'importConversationKeys': 'Konversationsschlüssel importieren',
      'importConversationKeysSubtitle': 'Schlüssel aus Datei wiederherstellen (z. B. nach Gerätewechsel)',
      'securityAuditTitle': 'Sicherheitsprüfung',
      'runAgain': 'Erneut ausführen',
      'chatRoomTitle': 'Chatraum',
      'errorLoadingSession': 'Fehler beim Laden der Sitzung',
      'activeChatsTitle': 'Aktive Chats',
      'noActiveChats': 'Keine aktiven Chats',
      'chatWithStudent': 'Chat mit %s',
      'filterToday': 'Heute',
      'filterYesterday': 'Gestern',
      'filterThisWeek': 'Diese Woche',
      'filterClear': 'Zurücksetzen',
      'noConversationId': 'Keine Konversations-ID',
      'nameLabel': 'Name',
      'accessCodeHint': 'XXXXXX',
      'adminSelectionTitle': 'Admin-Auswahl',
      'connectionSettingsTitle': 'Verbindungseinstellungen',
      'securityAuditSectionTitle': 'Sicherheitsprüfung',
      'conversationKeysSectionTitle': 'Konversationsschlüssel (Multi-Gerät)',
      'verifyEncryptionAndKeyStorage': 'Verschlüsselung und Schlüsselspeicherung prüfen',
      'totalMessages': 'Gesamtnachrichten',
      'activeConversations': 'Aktive Gespräche',
      'unreadMessages': 'Ungelesen',
      'averagePerDay': 'Ø pro Tag',
      'messageHistory': 'Nachrichtenverlauf',
      'noDataAvailable': 'Keine Daten verfügbar',
      'averageFirstResponse': 'Erste Antwortzeit',
      'averageResponseTime': 'Durchschnittliche Antwortzeit',
      'responseRate': 'Antwortquote',
      'responseTimes': 'Antwortzeiten',
      'dateRangeLabel': 'Zeitraum:',
      'exportPdfTooltip': 'Als PDF exportieren',
      'exportSuccess': 'Bericht exportiert',
      'exportError': 'Export fehlgeschlagen',
      'lastUpdated': 'Aktualisiert',
      'lastUpdatedMinutesAgo': 'Aktualisiert vor %s Min.',
      'forceRefresh': 'Aktualisieren',
      'vsLastWeek': 'vs. letzte Woche',
      'vsLastMonth': 'vs. letzten Monat',
      'vsPreviousPeriod': 'vs. Vorperiode',
      'trendUp': 'Anstieg',
      'trendDown': 'Rückgang',
      'trendStable': 'Stabil',
      'last7Days': 'Letzte 7 Tage',
      'last30Days': 'Letzte 30 Tage',
      'thisMonth': 'Diesen Monat',
      'adminPerformance': 'Admin-Leistung',
      'leaderboard': 'Bestenliste',
      'topPerformer': 'Top-Performer',
      'conversationsHandled': 'Bearbeitete Gespräche',
      'messagesPerDay': 'Nachrichten pro Tag',
      'rank': 'Rang',
      'messagesSent': 'Gesendete Nachrichten',
      'auth_error_email_required': 'Bitte E-Mail eingeben.',
      'auth_error_password_required': 'Bitte Passwort eingeben.',
      'auth_error_code_required': 'Bitte Zugangscode eingeben.',
      'auth_error_code_invalid': 'Ungültiger oder unbekannter Zugangscode.',
      'auth_error_code_expired': 'Dieser Zugangscode ist abgelaufen.',
      'auth_error_code_used': 'Dieser Code wurde bereits verwendet.',
      'auth_error_code_revoked': 'Dieser Zugangscode wurde widerrufen.',
      'auth_error_user_not_found': 'Kein Konto für diese E-Mail gefunden.',
      'auth_error_wrong_password': 'Falsches Passwort.',
      'auth_error_user_disabled': 'Dieses Konto wurde deaktiviert.',
      'auth_error_too_many_requests': 'Zu viele Versuche. Bitte später erneut versuchen.',
      'auth_error_anonymous_disabled': 'Anonymer Zugang ist nicht verfügbar.',
      'auth_error_unknown': 'Etwas ist schiefgelaufen. Bitte erneut versuchen.',
    },
  };
}
