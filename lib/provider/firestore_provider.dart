import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../models/administrator.dart';

class FirestoreProvider with ChangeNotifier{
  late FirebaseFirestore _firestore;

  FirebaseFirestore get firestore => _firestore;

  Future<void> initialize() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    notifyListeners(); // Notify listeners about initialization
  }

  // Add additional methods specific to your Firestore operations here
  Future<void> saveAdministrator(Administrator admin) async {
    final docRef = _firestore.collection('administrators').doc(admin.uid);
    await docRef.set(admin.toMap()); // Convert administrator object to a map
  }

  Future<Administrator?> getAdministrator(String uid) async {
    final docRef = _firestore.collection('administrators').doc(uid);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      return Administrator.fromMap(data);
    } else {
      return null;  // Handle case where document doesn't exist
    }
  }

  @override
  void dispose() {
    // Clean up resources (optional)
    super.dispose();
  }
}