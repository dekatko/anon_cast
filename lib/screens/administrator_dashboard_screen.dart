import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/chat_session.dart';
import '../screens/administrator_chat_dashboard_screen.dart'; // Import Chat Dashboard Screen
import '../screens/administrator_system_settings_screen.dart'; // Import Settings Screen (replace with actual class name)

class AdministratorDashboardScreen extends StatefulWidget {
  const AdministratorDashboardScreen({super.key});

  @override
  _AdministratorDashboardScreenState createState() => _AdministratorDashboardScreenState();
}

class _AdministratorDashboardScreenState extends State<AdministratorDashboardScreen> {
  final _chatBox = Hive.box<ChatSession>('chats'); // Replace 'chats' with your actual box name
  int _currentIndex = 0; // Index for current navigation bar item

  @override
  Widget build(BuildContext context) {
    final screens = [
      const AdministratorChatDashboardScreen(), // Add your chat dashboard screen
      const AdministratorSystemSettingsScreen(), // Add your system settings screen
      // Add more screens as needed
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Dashboard'),
      ),
      body: screens[_currentIndex], // Display current navigation bar screen
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Fixed icons at the bottom
        currentIndex: _currentIndex, // Set current index
        onTap: (index) => setState(() => _currentIndex = index), // Update index on tap
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          // Add more items for additional screens
        ],
      ),
    );
  }
}