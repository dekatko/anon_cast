import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../services/authentication_service.dart';
import 'administrator_login_screen.dart';
import 'chat_screen.dart';

final log = Logger();

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
      backgroundColor: Colors.lightBlueAccent, // Light blue background
      appBar: AppBar(
        title: const Text('Anon-Cast'), // Header text
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Optional username/ID field with a more playful font
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Username/ID (Optional)',
                  labelStyle: TextStyle(color: Colors.teal), // Playful teal color
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.tealAccent, width: 2.0), // Teal accent border when focused
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () {
                  log.i('Anonymous Login button pressed');
                  _loginAnonymousUser();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent, // Light pink pastel
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0), // Rounded corners
                  ),
                  minimumSize: const Size(double.infinity, 50.0), // Wider button
                ),
                child: const Text(
                  'Anonymous Login',
                  style: TextStyle(color: Colors.black), // Black text for better contrast
                ),
              ),
              const SizedBox(height: 20.0),
              TextButton(
                onPressed: () {
                  log.i('Administrator Login button pressed');
                  // Navigate to administrator login screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AdministratorLoginScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal, // Teal text color
                ),
                child: const Text(
                  'Administrator Login',
                  style: TextStyle(fontWeight: FontWeight.bold), // Bold text for emphasis
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginAnonymousUser() async {
    final user = await AuthenticationService().signInAnonymously();
    var uid = user?.uid;
    log.i("_loginAnonymousUser() - ");

    // Handle successful login
    if (user != null) {
      // Open the user box if not already opened
      final userBox = Hive.box<User>('users');

      // Check if a user with this uid already exists (optional)
      final existingUser = userBox.get(uid);
      if (existingUser == null) {
        // Create and save a new anonymous user if it doesn't exist
        final anonymousUser = User(
          id: uid!, // Use the uid from Firebase
          name: 'Anonymous',
          role: UserRole.student,
          password: '', // Empty password for anonymous user
        );
        userBox.put(uid, anonymousUser);
      }

      // Successful login, navigate to ChatScreen
      log.i("Pushing to ChatScreen...");
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => ChatScreen()));
    } else {
      // Handle login failure (optional: show an error message)
    }
  }
}
