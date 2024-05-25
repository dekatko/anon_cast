import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/administrator.dart';
import '../provider/firestore_provider.dart';

final log = Logger();

class AdministratorRegisterScreen extends StatefulWidget {
  final FirestoreProvider firestoreProvider; // Declare as a field

  const AdministratorRegisterScreen({super.key, required this.firestoreProvider});

  @override
  _AdministratorRegisterScreenState createState() => _AdministratorRegisterScreenState();
}

class _AdministratorRegisterScreenState extends State<AdministratorRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _errorMessage = ''; // String to store login error message

  bool _isLoading = false; // Flag for registration progress

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Register'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
                onChanged: (value) => setState(() => _name = value),
              ),
              const SizedBox(height: 10.0),
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
              const SizedBox(height: 10.0),
              Text(
                _errorMessage, // Display error message below text fields
                style: TextStyle(color: Colors.red, fontSize: 14.0),
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

      )
      ),
    );
  }

  Future<void> registerAdministrator() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true; // Set loading state to true
        _errorMessage = ''; // Clear any previous error message
      });

      try {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // Create and potentially save the administrator object (optional)
        final admin = Administrator(
            uid: userCredential.user!.uid,
            adminCode: generateAdminCode(),
            email: _email,
            name: _name
        );

        await widget.firestoreProvider.saveAdministrator(admin);

        //TODO: Is Chat Room created upon registry of Administrator? Or is it manually created by the Administrator?
        //Answer: When admin registers, a "Admin Code" is generated. This code can then be used by users during Anonymous Login to get into the right Chat Room
        //TODO: Maybe Admin can create different rooms for different purposes. Room for Bullying, Room for questions, etc.
        //TODO: Upon creation each room has its own unique registry code, through which students can log right into the chat room?

        // ... (Optional) Save administrator data using Hive or other storage

        log.i("Administrator registration successful!");
        // Navigate back to AdministratorLoginScreen after successful registration
        Navigator.pop(context);
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false; // Set loading state to false
          _errorMessage = e.message!; // Update error message
        });
        log.e("Administrator registration failed: ${e.message}");
        // Handle registration errors (e.g., show error message)
      }
    }
  }

  String generateAdminCode() {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += characters[random.nextInt(characters.length)];
    }
    return code.toUpperCase();
  }
}