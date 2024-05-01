import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/authentication_service.dart';
import 'chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false; // Flag for login progress indicator
  UserRole selectedRole = UserRole.student;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Optional username/ID field
            const TextField(
              decoration: InputDecoration(
                labelText: 'Username/ID (Optional)',
              ),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () => _loginAnonymousUser(),
              // Direct call to the method
              child: const Text('Login'),
            ),
            const SizedBox(height: 20.0),
            TextButton(
              onPressed: () {
                // Navigate to administrator login screen
              },
              child: const Text('Administrator Login'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginAnonymousUser() async {
    final user = await AuthenticationService().signInAnonymously();
    // Handle successful student login
    if (user != null) {
      // Successful login, navigate to ChatScreen
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => ChatScreen()));
    } else {
      // Handle login failure (optional: show an error message)
    }
  }
}
