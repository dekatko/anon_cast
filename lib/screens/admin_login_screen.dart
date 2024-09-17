import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../provider/firestore_provider.dart';
import 'admin_dashboard_screen.dart';
import 'admin_register_screen.dart';

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
              style: const TextStyle(color: Colors.red, fontSize: 12.0),
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
                  onPressed: () => pushToAdminRegister(),
                  child: const Text('Register'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void pushToAdminRegister() async {
    final firestoreProvider = context.read<FirestoreProvider>(); // Access provider
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdministratorRegisterScreen(
          firestoreProvider: firestoreProvider, // Provide the instance
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
}
