import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstraction for the encrypted message relay (production: Firestore; tests: in-memory).
/// Allows unit testing [MessageService] without Firebase.
abstract interface class MessageRelay {
  /// Adds a message document; returns the document id.
  Future<String> add(Map<String, dynamic> data);

  /// Stream of snapshots for messages in [conversationId], ordered by timestamp ascending.
  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String conversationId);

  /// Fetches all message documents for [conversationId] once (e.g. for key rotation).
  Future<List<Map<String, dynamic>>> getMessages(String conversationId);

  /// Updates an existing message document (e.g. re-encrypted content after rotation).
  Future<void> update(String messageId, Map<String, dynamic> data);

  /// Deletes the message document [messageId]. Idempotent.
  Future<void> delete(String messageId);
}

/// Firestore implementation of [MessageRelay] (top-level `messages` collection).
class FirestoreMessageRelay implements MessageRelay {
  FirestoreMessageRelay(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _messagesCollection = 'messages';

  @override
  Future<String> add(Map<String, dynamic> data) async {
    final ref = _firestore.collection(_messagesCollection).doc();
    await ref.set(data);
    return ref.id;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String conversationId) {
    return _firestore
        .collection(_messagesCollection)
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final snapshot = await _firestore
        .collection(_messagesCollection)
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .get();
    return snapshot.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
  }

  @override
  Future<void> update(String messageId, Map<String, dynamic> data) async {
    await _firestore.collection(_messagesCollection).doc(messageId).update(data);
  }

  @override
  Future<void> delete(String messageId) async {
    await _firestore.collection(_messagesCollection).doc(messageId).delete();
  }
}
