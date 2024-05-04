import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

import '../models/user.dart';
import '../models/user_role.dart';

final log = Logger();

class AdministratorRegisterScreen extends StatefulWidget {
  const AdministratorRegisterScreen({super.key});

  @override
  _AdministratorRegisterScreenState createState() => _AdministratorRegisterScreenState();
}

class _AdministratorRegisterScreenState extends State<AdministratorRegisterScreen> {
  String _username = '';
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
                labelText: 'Username',
              ),
              onChanged: (value) => setState(() => _username = value),
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
              onPressed: () => _registerUser(),
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerUser() async {
    // Form validation (optional)
    if (_username.isEmpty || _password.isEmpty || _confirmPassword.isEmpty) {
      // Show a dialog or display an error message
      return;
    }

    if (_password != _confirmPassword) {
      // Show an error message about password mismatch
      return;
    }

    // Create a new User object assuming your User class has these properties
    final newUser = User(
      id: UniqueKey().toString(), // Assuming you need an ID
      name: _username, // Assuming username maps to User.name
      role: UserRole.primary_admin, // Or appropriate role for admin
    );

    // Open Hive box for User data (assuming a box named "users")
    final userBox = await Hive.openBox<User>('users');

    try {
      // Add the user to the Hive box
      await userBox.add(newUser);

      // Show success message or perform other actions (optional)
      log.i('Administrator registered successfully!');
      Navigator.pop(context); // Navigate back to AdministratorLoginScreen
    } catch (error) {
      // Handle potential errors during Hive operation
      log.e('Error registering user: $error');
      // Show an error message to the user (optional)
    }
  }
}