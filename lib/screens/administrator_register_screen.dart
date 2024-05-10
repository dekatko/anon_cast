import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

import '../models/administrator.dart';
import '../models/user_role.dart';

final log = Logger();

class AdministratorRegisterScreen extends StatefulWidget {
  const AdministratorRegisterScreen({super.key});

  @override
  _AdministratorRegisterScreenState createState() => _AdministratorRegisterScreenState();
}

class _AdministratorRegisterScreenState extends State<AdministratorRegisterScreen> {
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isLoading = false; // Flag for registration progress

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
              onChanged: (value) => setState(() => _email = value),
            ),
            const SizedBox(height: 10.0),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
              onChanged: (value) => setState(() => _password = value),
            ),
            const SizedBox(height: 10.0),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
              ),
              obscureText: true,
              onChanged: (value) => setState(() => _confirmPassword = value),
            ),
            const SizedBox(height: 20.0),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: () => registerAdministrator(),
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _registerUser() async {
  //   // Form validation (optional)
  //   if (_username.isEmpty || _password.isEmpty || _confirmPassword.isEmpty) {
  //     // Show a dialog or display an error message
  //     return;
  //   }
  //
  //   if (_password != _confirmPassword) {
  //     // Show an error message about password mismatch
  //     return;
  //   }
  //
  //   // Create a new User object assuming your User class has these properties
  //   final newUser = User(
  //     id: UniqueKey().toString(), // Assuming you need an ID
  //     name: _username, // Assuming username maps to User.name
  //     role: UserRole.primary_admin,
  //     password: _password, // Or appropriate role for admin
  //   );
  //
  //   // Open Hive box for User data (assuming a box named "users")
  //   final userBox = await Hive.openBox<User>('users');
  //
  //   try {
  //     // Add the user to the Hive box
  //     await userBox.add(newUser);
  //
  //     // Show success message or perform other actions (optional)
  //     log.i('Administrator registered successfully!');
  //     Navigator.pop(context); // Navigate back to AdministratorLoginScreen
  //   } catch (error) {
  //     // Handle potential errors during Hive operation
  //     log.e('Error registering user: $error');
  //     // Show an error message to the user (optional)
  //   }
  // }

  Future<void> registerAdministrator() async {
    final auth = FirebaseAuth.instance;
    try {
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
      );

      // Generate a unique ID for the administrator
      final administratorId = userCredential.user!.uid;

      // Create and potentially save the administrator object (optional)
      final administrator = Administrator(
        id: administratorId,
        email: _email,
        password: _password, // Consider hashing password before storing
      );
      //TODO: Is Chat Room created upon registry of Administrator? Or is it manually created by the Administrator?
      //TODO: Maybe Admin can create different rooms for different purposes. Room for Bullying, Room for questions, etc.
      //TODO: Upon creation each room has its own unique registry code, through which students can log right into the chat room?

      // ... (Optional) Save administrator data using Hive or other storage

      log.i("Administrator registration successful!");
    } on FirebaseAuthException catch (e) {
      log.e("Administrator registration failed: ${e.message}");
      // Handle registration errors (e.g., show error message)
    }
  }
}