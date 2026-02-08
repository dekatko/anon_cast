import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/access_code.dart';

/// Active user stats derived from messages.
class ActiveUserStats {
  const ActiveUserStats({
    this.totalAnonymousUsers = 0,
    this.messagesLast24h = 0,
    this.messagesLast7d = 0,
  });

  final int totalAnonymousUsers;
  final int messagesLast24h;
  final int messagesLast7d;
}

/// Provides access codes from Firestore and active user statistics.
class AccessCodesProvider extends ChangeNotifier {
  AccessCodesProvider({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;
  static const _chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // exclude ambiguous 0,O,1,I

  List<AccessCode> _codes = [];
  List<AccessCode> get codes => List.unmodifiable(_codes);

  ActiveUserStats _activeStats = const ActiveUserStats();
  ActiveUserStats get activeStats => _activeStats;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;
  bool get hasError => _error != null;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  AccessCodeStatus? _filterStatus;
  AccessCodeStatus? get filterStatus => _filterStatus;

  List<AccessCode> get filteredCodes {
    var list = _codes;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) => c.code.toLowerCase().contains(q)).toList();
    }
    if (_filterStatus != null) {
      list = list.where((c) => c.status == _filterStatus).toList();
    }
    return list;
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _codesSub;

  /// Generate a 6-character alphanumeric code (no ambiguous chars).
  String generateCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _chars[r.nextInt(_chars.length)]).join();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setFilterStatus(AccessCodeStatus? status) {
    _filterStatus = status;
    notifyListeners();
  }

  void startListening() {
    _codesSub?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _codesSub = _firestore
        .collection('access_codes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _codes = snapshot.docs
                .map((d) => AccessCode.fromFirestore(d))
                .toList();
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (e, st) {
            _error = e;
            _isLoading = false;
            notifyListeners();
          },
        );

    _loadActiveUserStats();
  }

  Future<void> _loadActiveUserStats() async {
    try {
      final now = DateTime.now();
      final dayAgo = now.subtract(const Duration(hours: 24));
      final weekAgo = now.subtract(const Duration(days: 7));

      final messagesSnap = await _firestore
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();

      final senders = <String>{};
      int last24 = 0, last7 = 0;
      for (final doc in messagesSnap.docs) {
        final data = doc.data();
        final ts = data['timestamp'];
        DateTime msgTime = DateTime.now();
        if (ts is Timestamp) msgTime = ts.toDate();
        if (ts is int) msgTime = DateTime.fromMillisecondsSinceEpoch(ts);
        final senderId = data['senderId'] as String? ?? '';
        if (senderId.isNotEmpty) senders.add(senderId);
        if (msgTime.isAfter(dayAgo)) last24++;
        if (msgTime.isAfter(weekAgo)) last7++;
      }

      _activeStats = ActiveUserStats(
        totalAnonymousUsers: senders.length,
        messagesLast24h: last24,
        messagesLast7d: last7,
      );
      notifyListeners();
    } catch (_) {
      notifyListeners();
    }
  }

  /// Create a new access code. [expiryDays] and [singleUse] from dialog.
  Future<AccessCode> createCode({
    required int expiryDays,
    required bool singleUse,
    String? adminId,
  }) async {
    final code = generateCode();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: expiryDays));

    final ref = _firestore.collection('access_codes').doc();
    final ac = AccessCode(
      id: ref.id,
      code: code,
      status: AccessCodeStatus.active,
      createdAt: now,
      expiresAt: expiresAt,
      singleUse: singleUse,
      createdByAdminId: adminId,
    );
    await ref.set(ac.toMap());
    return ac;
  }

  Future<void> revokeCode(String id) async {
    final ref = _firestore.collection('access_codes').doc(id);
    await ref.update({
      'status': 'revoked',
      'revokedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCode(String id) async {
    await _firestore.collection('access_codes').doc(id).delete();
  }

  void stopListening() {
    _codesSub?.cancel();
    _codesSub = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
