import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstraction for the encrypted message relay (production: Firestore; tests: in-memory).
/// Allows unit testing [MessageService] without Firebase.
abstract interface class MessageRelay {
  /// Adds a message document; returns the document id.
  Future<String> add(Map<String, dynamic> data);

  /// Stream of snapshots for messages in [conversationId], ordered by timestamp ascending.
  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String conversationId);

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
  Future<void> delete(String messageId) async {
    await _firestore.collection(_messagesCollection).doc(messageId).delete();
  }
}
