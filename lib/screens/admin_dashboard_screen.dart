import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_session.dart';
import '../provider/offline_provider.dart';
import '../widgets/offline_banner.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/user_management_screen.dart';
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
    final l10n = AppLocalizations.of(context);
    final screens = [
      const AdminDashboardScreen(),
      const UserManagementScreen(),
      const AdminRotationStatusScreen(),
      const AdministratorSystemSettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.administratorDashboardTitle),
      ),
      body: Column(
        children: [
          Consumer<OfflineProvider?>(
            builder: (context, offline, _) {
              if (offline == null) return const SizedBox.shrink();
              return OfflineBanner(
                isOffline: offline.isOffline,
                isSyncing: offline.isSyncing,
                pendingCount: offline.pendingCount,
                failedCount: offline.failedCount,
                onRetry: offline.failedCount > 0 ? offline.retryAllFailed : null,
              );
            },
          ),
          Expanded(child: screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.inbox),
            label: l10n.navMessages,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: l10n.navUsers,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.security),
            label: l10n.navRotation,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l10n.settingsLabel,
          ),
        ],
      ),
    );
  }
}