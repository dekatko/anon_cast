import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/user.dart';

class AdministratorDashboardScreen extends StatefulWidget {
  const AdministratorDashboardScreen({super.key});

  @override
  _AdministratorDashboardScreenState createState() => _AdministratorDashboardScreenState();
}

class _AdministratorDashboardScreenState extends State<AdministratorDashboardScreen> {
  final _userBox = Hive.box<User>('users');
  String _selectedConnection = 'Wifi Direct'; // Default selection

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('User Management'),
            const SizedBox(height: 10.0),
            Expanded(
              child: ListView.builder(
                itemCount: _userBox.length,
                itemBuilder: (context, index) {
                  final user = _userBox.getAt(index)!;
                  return ListTile(
                    title: Text(user.name),
                    subtitle: Text(user.role.toString()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit User icon (optional)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => {/* Edit user functionality */},
                        ),
                        // Delete User icon (optional)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => {/* Delete user confirmation dialog */},
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const Text('System Settings'),
            const SizedBox(height: 10.0),
            DropdownButton<String>(
              value: _selectedConnection,
              items: [
                DropdownMenuItem<String>(
                  value: 'Wifi Direct',
                  child: Text('Wifi Direct'),
                ),
                DropdownMenuItem<String>(
                  value: 'Remote Server',
                  child: Text('Remote Server'),
                ),
                DropdownMenuItem<String>(
                  value: 'Own Server',
                  child: Text('Own Server'),
                ),
              ],
              onChanged: (value) => setState(() => _selectedConnection = value!),
            ),
            // Add additional system settings options here (optional)
          ],
        ),
      ),
    );
  }
}