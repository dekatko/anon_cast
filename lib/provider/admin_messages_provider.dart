import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_message.dart';

/// Filter for the admin message list.
class AdminMessageFilter {
  const AdminMessageFilter({
    this.status,
    this.dateFrom,
    this.dateTo,
    this.searchQuery,
  });

  final MessageStatus? status;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? searchQuery;

  AdminMessageFilter copyWith({
    MessageStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? searchQuery,
  }) {
    return AdminMessageFilter(
      status: status ?? this.status,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Provides real-time admin messages from Firestore 'messages' collection
/// with filtering, search, and unread count.
class AdminMessagesProvider extends ChangeNotifier {
  AdminMessagesProvider({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection('messages').withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
            toFirestore: (v, _) => v,
          );

  AdminMessageFilter _filter = const AdminMessageFilter();
  AdminMessageFilter get filter => _filter;

  List<AdminMessage> _allMessages = [];
  List<AdminMessage> get allMessages => List.unmodifiable(_allMessages);

  List<AdminMessage> _filteredMessages = [];
  List<AdminMessage> get filteredMessages => List.unmodifiable(_filteredMessages);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;
  bool get hasError => _error != null;

  int get unreadCount =>
      _allMessages.where((m) => m.status == MessageStatus.unread).length;

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    Query<Map<String, dynamic>> q = _messages.orderBy('timestamp', descending: true);
    return q.snapshots();
  }

  /// Call once to start listening to Firestore. The stream is active until
  /// the provider is disposed or [stopListening] is called.
  void startListening(void Function() onUpdate) {
    _subscription?.cancel();

    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _messagesStream().listen(
      (snapshot) {
        _allMessages = snapshot.docs
            .map((d) => AdminMessage.fromFirestore(d))
            .toList();
        _applyFilter();
        _isLoading = false;
        _error = null;
        onUpdate();
        notifyListeners();
      },
      onError: (e, st) {
        _error = e;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  void _applyFilter() {
    var list = _allMessages;

    if (_filter.status != null) {
      list = list.where((m) => m.status == _filter.status).toList();
    }
    if (_filter.dateFrom != null) {
      list = list.where((m) => !m.timestamp.isBefore(_filter.dateFrom!)).toList();
    }
    if (_filter.dateTo != null) {
      final end = DateTime(
        _filter.dateTo!.year,
        _filter.dateTo!.month,
        _filter.dateTo!.day,
        23,
        59,
        59,
      );
      list = list.where((m) => !m.timestamp.isAfter(end)).toList();
    }
    if (_filter.searchQuery != null && _filter.searchQuery!.isNotEmpty) {
      final q = _filter.searchQuery!.toLowerCase();
      list = list.where((m) {
        if (m.preview?.toLowerCase().contains(q) ?? false) return true;
        if (m.senderId.toLowerCase().contains(q)) return true;
        if (m.conversationId.toLowerCase().contains(q)) return true;
        return false;
      }).toList();
    }

    _filteredMessages = list;
  }

  void setFilter(AdminMessageFilter f) {
    _filter = f;
    _applyFilter();
    notifyListeners();
  }

  void setStatusFilter(MessageStatus? status) {
    setFilter(_filter.copyWith(status: status));
  }

  void setDateRange(DateTime? from, DateTime? to) {
    setFilter(_filter.copyWith(dateFrom: from, dateTo: to));
  }

  void setSearchQuery(String? query) {
    setFilter(_filter.copyWith(searchQuery: query));
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    // Stream will push new data; we just trigger a visual refresh.
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({'status': 'read'});
  }

  Future<void> markAsResolved(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({'status': 'resolved'});
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
