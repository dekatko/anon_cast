import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

import '../models/user.dart';
import '../models/user_role.dart';
import 'administrator_dashboard_screen.dart';
import 'administrator_register_screen.dart';

final log = Logger();

class AdministratorLoginScreen extends StatefulWidget {
  const AdministratorLoginScreen({super.key});

  @override
  _AdministratorLoginScreenState createState() => _AdministratorLoginScreenState();
}

class _AdministratorLoginScreenState extends State<AdministratorLoginScreen> {
  String _email = '';
  String _password = '';
  bool _isLoading = false; // Flag for login progress
  String _errorMessage = ''; // String to store login error message

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
            const SizedBox(height: 20.0),
            Text(
              _errorMessage, // Display login error message (if any)
              style: TextStyle(color: Colors.red, fontSize: 12.0),
            ),
            Row(
              // Place Login and Register buttons side-by-side
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = ''; // Clear previous error
                    });
                    final userCredential = await loginAdministrator();
                    setState(() => _isLoading = false);
                    if (userCredential != null) {
                      // Login successful, navigate to dashboard
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdministratorDashboardScreen(),
                        ),
                      );
                    } else {
                      // Login failed, show error message
                      setState(() => _errorMessage = _errorMessage);
                    }
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

  Future<UserCredential?> loginAdministrator() async {
    final auth = FirebaseAuth.instance;
    try {
      if(_email == '') {
        _errorMessage = "No Email Entered!";
        return null;
      } else if(_password == '') {
        _errorMessage = "No Password Entered!";
        return null;
      }
      final userCredential = await auth.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );
      log.i("Administrator login successful!");
      return userCredential;
    } on FirebaseAuthException catch (e) {
      log.e("Administrator login failed: ${e.message}");
      // Handle login errors (e.g., show error message)
      _errorMessage = e.message!;
      return null;
    }
  }

  String getErrorMessage(String currentMessage) {
    // Map Firebase Auth exception codes to more user-friendly messages
    final errorMap = {
      'wrong-password': 'Incorrect email or password.',
      'user-not-found': 'The email you entered does not exist.',
      'invalid-email': 'Please enter a valid email address.',
      'user-disabled': 'This account has been disabled.',
      // Add more error codes and messages as needed
    };

    final errorCode = currentMessage.split(':').first.trim(); // Extract error code

    // Check if the error code exists in the map
    if (errorMap.containsKey(errorCode)) {
      return errorMap[errorCode]!;
    } else {
      // Default message for unknown errors
      return 'Login failed. Please try again.';
    }
  }
}
