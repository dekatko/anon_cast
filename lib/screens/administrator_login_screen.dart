import 'package:flutter/material.dart';

class AdminLoginScreen extends StatefulWidget {
  @override
  _AdminLoginScreenState createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  String _username = '';
  String _password = '';
  bool _isLoading = false; // Flag for login progress

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
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () {
                      // Implement login logic for administrator
                      // (validation, error handling, navigation)
                    },
                    child: const Text('Login'),
                  ),
          ],
        ),
      ),
    );
  }
}
