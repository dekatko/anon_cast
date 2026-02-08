import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/chat_session.dart';
import '../screens/admin_chat_dashboard_screen.dart';
import '../screens/admin_rotation_status_screen.dart';
import '../screens/admin_system_settings_screen.dart';

class AdministratorDashboardScreen extends StatefulWidget {
  const AdministratorDashboardScreen({super.key});

  @override
  State<AdministratorDashboardScreen> createState() =>
      _AdministratorDashboardScreenState();
}

class _AdministratorDashboardScreenState
    extends State<AdministratorDashboardScreen> {
  final _chatBox = Hive.box<ChatSession>('chat_sessions');
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const AdministratorChatDashboardScreen(),
      const AdminRotationStatusScreen(),
      const AdministratorSystemSettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Dashboard'),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Rotation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}