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
