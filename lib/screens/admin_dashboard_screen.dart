import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/chat_session.dart';
import 'admin/admin_dashboard.dart';
import 'admin_chat_dashboard_screen.dart';
import 'admin_rotation_status_screen.dart';
import 'admin_system_settings_screen.dart';

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
      const AdminDashboard(),
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
            icon: Icon(Icons.inbox),
            label: 'Messages',
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