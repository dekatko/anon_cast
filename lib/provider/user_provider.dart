import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/user.dart';

class UserProvider extends ChangeNotifier {
  User? _user;

  User? get user => _user;

  void setUser(User user) {
    _user = user;
    notifyListeners(); // Notify listeners when user changes
  }

  User? getUserById(String userId) {
    final userBox = Hive.box<User>('users');
    return userBox.get(userId);

    // Using Firestore:
    // final user = await firestore.collection('users').doc(userId).get();
    // return user.data() as User?;
  }
}