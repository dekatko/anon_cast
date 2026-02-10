import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_role.dart'; // Import the updated User model with UserRole

class AdminSelectionScreen extends StatefulWidget {
  const AdminSelectionScreen({Key? key}) : super(key: key);

  @override
  State<AdminSelectionScreen> createState() => _AdminSelectionScreenState();
}

class _AdminSelectionScreenState extends State<AdminSelectionScreen> {
  UserRole selectedRole = UserRole.primary_admin; // Initial selection

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminSelectionTitle),
      ),
      body: Center(
        child: DropdownButton<UserRole>(
          value: selectedRole,
          items: UserRole.values.map(buildDropdownMenuItem).toList(),
          onChanged: (value) => setState(() => selectedRole = value!),
        ),
      ),
    );
  }

  // Helper method to create DropdownMenuItem for each UserRole
  DropdownMenuItem<UserRole> buildDropdownMenuItem(UserRole role) {
    return DropdownMenuItem(
      value: role,
      child: Text(role
          .toString()
          .split('_')
          .join(' ')), // Convert enum to human-readable string
    );
  }
}
