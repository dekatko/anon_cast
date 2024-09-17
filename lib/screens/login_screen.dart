import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../models/user_role.dart';
import '../provider/user_provider.dart';
import '../services/authentication_service.dart';
import '../services/chat_service.dart';
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
  final TextEditingController _adminCodeController = TextEditingController();
  bool _isLoading = false; // Flag for login progress indicator
  String _errorMessage = '';
  UserRole selectedRole = UserRole.student;

  @override
  void dispose() {
    _usernameController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlueAccent, // Light blue background
      appBar: AppBar(
        title: const Text('Elly'), // Header text
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextField(
                controller: _adminCodeController,
                decoration: const InputDecoration(
                  labelText: 'Admin Code',
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
                    borderRadius:
                        BorderRadius.circular(20.0), // Rounded corners
                  ),
                  minimumSize:
                      const Size(double.infinity, 50.0), // Wider button
                ),
                child: const Text(
                  'Anonymous Login',
                  style: TextStyle(
                      color: Colors.black), // Black text for better contrast
                ),
              ),
              const SizedBox(height: 20.0),
              Text(
                _errorMessage, // Display login error message (if any)
                style: const TextStyle(color: Colors.red, fontSize: 12.0),
              ),
              TextButton(
                onPressed: () {
                  log.i('Administrator Login button pressed');
                  // Navigate to administrator login screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdministratorLoginScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal, // Teal text color
                ),
                child: const Text(
                  'Administrator Login',
                  style: TextStyle(
                      fontWeight: FontWeight.bold), // Bold text for emphasis
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
    final chatService = Provider.of<ChatService>(context, listen: false);

    var uid = user?.uid;
    var adminCode = _adminCodeController.text;
    log.i("_loginAnonymousUser() - uid: $uid, adminCode: $adminCode");

    // Combined check for user and adminCode
    if (uid != null && adminCode.isNotEmpty) {
      _setOrCreateHiveUserInProvider(context, uid);
      // Check for existing chat session (if user and adminCode are present)
      final existingChat =
          await chatService.getExistingOrNewChat(uid!, adminCode);
      if (existingChat != null) {
        log.i("Existing chat found, joining...");
        // Join the existing chat session
        // ... (your logic for joining based on existingChat data)
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ChatScreen(chatSession: existingChat)),
        );
        return; // Exit the function if existing chat is joined
      } else {
        log.i("No existing chat found, creating new chat...");
        // Create a new chat session
        // ... (your logic for creating a new chat session using uid and adminCode)
        final newChat = await chatService.createChat(uid!, adminCode);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ChatScreen(chatSession: newChat)),
        );
      }
    }
  }

  void _setOrCreateHiveUserInProvider(BuildContext context, String uid) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final userBox = Hive.box<User>('users');

    final existingUser = userBox.get(uid);
    if (existingUser == null) {
      final anonymousUser = User(
        id: uid!,
        name: 'Anonymous',
        role: UserRole.student,
      );
      userBox.put(uid, anonymousUser);
      userProvider.setUser(anonymousUser);
      log.i("getOrCreateUser() - Created new User and set in Provider");
    } else {
      userProvider.setUser(existingUser);
      log.i("getOrCreateUser() - Set Existing User in Provider");
    }
  }
}
