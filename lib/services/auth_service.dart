import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result of successful anonymous sign-in. Contains Firebase user and admin id
/// for resolving the chat session.
class AnonymousAuthResult {
  const AnonymousAuthResult({required this.user, required this.adminId});
  final User user;
  final String adminId;
}

/// Auth error with a localizable message key (use with AppLocalizations or map to DE/EN).
class AuthException implements Exception {
  const AuthException(this.messageKey, [this.debugMessage]);
  final String messageKey;
  final String? debugMessage;
  @override
  String toString() => debugMessage ?? messageKey;
}

/// Central auth: admin (email/password) and anonymous (code-based) with Firebase Auth.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// True if current user is signed in with email/password (admin).
  bool get isAdmin => currentUser != null && !currentUser!.isAnonymous;

  /// True if current user is anonymous (code-based).
  bool get isAnonymous => currentUser?.isAnonymous == true;

  /// Sign in admin with email and password.
  /// Throws [AuthException] with [AuthException.messageKey] for UI/localization.
  Future<User> signInAdmin(String email, String password) async {
    final e = email.trim();
    final p = password.trim();
    if (e.isEmpty) throw const AuthException('auth_error_email_required');
    if (p.isEmpty) throw const AuthException('auth_error_password_required');

    try {
      final cred = await _auth.signInWithEmailAndPassword(email: e, password: p);
      final user = cred.user;
      if (user == null) throw const AuthException('auth_error_unknown');
      return user;
    } on FirebaseAuthException catch (err) {
      throw AuthException(_adminAuthErrorKey(err.code), err.message);
    }
  }

  /// Verify [code] in Firestore (access_codes), sign in anonymously, mark code used, return user + adminId.
  /// Throws [AuthException] for invalid/expired/revoked code or auth errors.
  Future<AnonymousAuthResult> signInAnonymous(String code) async {
    final raw = code.trim().toUpperCase();
    if (raw.isEmpty) throw const AuthException('auth_error_code_required');

    final ac = await _validateAccessCodeOnly(raw);
    try {
      final cred = await _auth.signInAnonymously();
      final user = cred.user;
      if (user == null) throw const AuthException('auth_error_unknown');
      await _markCodeAsUsed(ac.id, user.uid);
      return AnonymousAuthResult(user: user, adminId: ac.createdByAdminId);
    } on FirebaseAuthException catch (err) {
      throw AuthException(_anonymousAuthErrorKey(err.code), err.message);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email. Throws [AuthException] on failure.
  Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim();
    if (e.isEmpty) throw const AuthException('auth_error_email_required');
    try {
      await _auth.sendPasswordResetEmail(email: e);
    } on FirebaseAuthException catch (err) {
      throw AuthException(_adminAuthErrorKey(err.code), err.message);
    }
  }

  Future<AccessCodeValidated> _validateAccessCodeOnly(String normalizedCode) async {
    final snapshot = await _firestore
        .collection('access_codes')
        .where('code', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw const AuthException('auth_error_code_invalid');
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    final status = data['status'] as String? ?? 'active';
    if (status != 'active') {
      if (status == 'revoked') throw const AuthException('auth_error_code_revoked');
      if (status == 'used') throw const AuthException('auth_error_code_used');
      throw const AuthException('auth_error_code_expired');
    }

    final expiresAt = data['expiresAt'];
    DateTime expiry = DateTime.now();
    if (expiresAt is Timestamp) expiry = expiresAt.toDate();
    if (expiresAt is int) expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt);
    if (DateTime.now().isAfter(expiry)) {
      throw const AuthException('auth_error_code_expired');
    }

    final createdByAdminId = data['createdByAdminId'] as String?;
    if (createdByAdminId == null || createdByAdminId.isEmpty) {
      throw const AuthException('auth_error_code_invalid');
    }

    return AccessCodeValidated(
      id: doc.id,
      createdByAdminId: createdByAdminId,
    );
  }

  /// For returning anonymous users: validate code and return adminId without signing in or marking used.
  /// Returns null if code is invalid, expired, or already used.
  Future<String?> getAdminIdForValidCode(String code) async {
    final raw = code.trim().toUpperCase();
    if (raw.isEmpty) return null;
    try {
      final ac = await _validateAccessCodeOnly(raw);
      return ac.createdByAdminId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _markCodeAsUsed(String docId, String usedByUserId) async {
    await _firestore.collection('access_codes').doc(docId).update({
      'status': 'used',
      'usedAt': FieldValue.serverTimestamp(),
      'usedByUserId': usedByUserId,
    });
  }

  String _adminAuthErrorKey(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-email':
        return 'auth_error_user_not_found';
      case 'wrong-password':
      case 'invalid-credential':
        return 'auth_error_wrong_password';
      case 'user-disabled':
        return 'auth_error_user_disabled';
      case 'too-many-requests':
        return 'auth_error_too_many_requests';
      default:
        return 'auth_error_unknown';
    }
  }

  String _anonymousAuthErrorKey(String code) {
    if (code == 'operation-not-allowed') return 'auth_error_anonymous_disabled';
    return 'auth_error_unknown';
  }
}

class AccessCodeValidated {
  const AccessCodeValidated({required this.id, required this.createdByAdminId});
  final String id;
  final String createdByAdminId;
}
