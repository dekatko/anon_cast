import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/chat_session.dart';
import '../models/user.dart';

class AdministratorDashboardScreen extends StatefulWidget {
  const AdministratorDashboardScreen({super.key});

  @override
  _AdministratorDashboardScreenState createState() => _AdministratorDashboardScreenState();
}

class _AdministratorDashboardScreenState extends State<AdministratorDashboardScreen>
    with TickerProviderStateMixin {

  final _chatBox = Hive.box<ChatSession>('chats'); // Replace 'chats' with your actual box name
  bool _isMenuOpen = false; // Flag for menu open/closed state
  late final AnimationController _menuController;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this, // Use the TickerProvider from the StatefulWidget
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Dashboard'),
        // Add a leading menu button if desired (optional)
      ),
      body: Stack(
        children: [
          // Main content area
          buildContent(),
          // Slide-in menu for system settings
          SlideTransition(
            position: Tween<Offset>(
              // duration: const Duration(milliseconds: 200),
              begin: const Offset(-1.0, 0.0), // Menu starts off-screen
              end: const Offset(0.0, 0.0), // Menu slides in
            ).animate(CurvedAnimation(parent: _menuController, curve: Curves.easeIn)),
            child: Material(
              color: Colors.blueGrey.shade700, // Menu background color
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text('System Settings', style: TextStyle(color: Colors.white, fontSize: 18.0)),
                    Divider(color: Colors.white),
                    // Add system settings options here (e.g., DropdownButtons, TextFields)
                    // ...
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    return GestureDetector(
      // Detect left swipe to open menu
      onHorizontalDragEnd: (details) => {
        if (details.primaryVelocity! > 0.0) // Left swipe
          setState(() => _isMenuOpen = true),
      },
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Active Chats'),
            const SizedBox(height: 10.0),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // Adjust grid layout as needed
                children: List.generate(_chatBox.length, (index) {
                  final chat = _chatBox.getAt(index)!;
                  // Customize chat square UI based on your chat model
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Text(chat.name), // Replace with appropriate chat information
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}