import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

import '../models/user.dart';
import '../models/user_role.dart';
import 'administrator_register_screen.dart';

final log = Logger();

class AdministratorLoginScreen extends StatefulWidget {
  const AdministratorLoginScreen({super.key});

  @override
  _AdministratorLoginScreenState createState() => _AdministratorLoginScreenState();
}

class _AdministratorLoginScreenState extends State<AdministratorLoginScreen> {
  String _username = '';
  String _password = '';
  bool _isLoading = false; // Flag for login progress

  // final _userBox = Hive.box<User>('users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Login'),
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
            const SizedBox(height: 20.0),
            Row(
              // Place Login and Register buttons side-by-side
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: () {
                    // Implement login logic for administrator
                    // (validation, error handling, navigation)
                  },
                  child: const Text('Login'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdministratorRegisterScreen()),
                  ),
                  child: const Text('Register'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerUser() async {
    // Form validation (optional)
    if (_username.isEmpty || _password.isEmpty) {
      // Show a dialog or display an error message
      return;
    }

    // Create a new User object using your existing User class
    final newUser = User(
      id: UniqueKey().toString(), // Assuming you need an ID
      name: _username, // Assuming username maps to User.name
      role: UserRole.primary_admin, // Or appropriate role for admin
    );

    // Add the user to the Hive box
    // await _userBox.add(newUser);

    // Show success message or perform other actions (optional)
    print('User registered successfully!');
  }
}
