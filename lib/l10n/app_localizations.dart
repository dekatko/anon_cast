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
    },
  };
}
