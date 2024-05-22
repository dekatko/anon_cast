import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class FirestoreProvider with ChangeNotifier{
  late FirebaseFirestore _firestore;

  FirebaseFirestore get firestore => _firestore;

  Future<void> initialize() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    notifyListeners(); // Notify listeners about initialization
  }

  // Add additional methods specific to your Firestore operations here

  @override
  void dispose() {
    // Clean up resources (optional)
    super.dispose();
  }
}