import 'package:flutter/material.dart';

enum ConnectionType { wifiDirect, externalServer, localServer }

class AdministratorSystemSettingsScreen extends StatefulWidget {
  const AdministratorSystemSettingsScreen({super.key});

  @override
  AdministratorSystemSettingsScreenState createState() => AdministratorSystemSettingsScreenState();
}

class AdministratorSystemSettingsScreenState extends State<AdministratorSystemSettingsScreen> {
  ConnectionType _selectedConnectionType = ConnectionType.wifiDirect; // Initial selection

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Settings Section
            const Text(
              'Connection Settings',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 1.0),
            ListTile(
              title: const Text('Wi-Fi Direct'),
              trailing: Radio<ConnectionType>(
                value: ConnectionType.wifiDirect,
                groupValue: _selectedConnectionType,
                onChanged: (value) => setState(() => _selectedConnectionType = value!),
              ),
            ),
            ListTile(
              title: const Text('External Server'),
              trailing: Radio<ConnectionType>(
                value: ConnectionType.externalServer,
                groupValue: _selectedConnectionType,
                onChanged: (value) => setState(() => _selectedConnectionType = value!),
              ),
            ),
            ListTile(
              title: const Text('Local Server'),
              trailing: Radio<ConnectionType>(
                value: ConnectionType.localServer,
                groupValue: _selectedConnectionType,
                onChanged: (value) => setState(() => _selectedConnectionType = value!),
              ),
            ),
            // Add more settings sections here...
          ],
        ),
      ),
    );
  }
}