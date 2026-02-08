import 'package:flutter/material.dart';

import '../services/sync_service.dart';

enum ConnectionType { wifiDirect, externalServer, localServer }

class AdministratorSystemSettingsScreen extends StatefulWidget {
  const AdministratorSystemSettingsScreen({super.key});

  @override
  AdministratorSystemSettingsScreenState createState() => AdministratorSystemSettingsScreenState();
}

class AdministratorSystemSettingsScreenState extends State<AdministratorSystemSettingsScreen> {
  ConnectionType _selectedConnectionType = ConnectionType.wifiDirect; // Initial selection
  final SyncService _syncService = SyncService();

  /// Export: prompt password → exportEncryptedKeys → offer file download (or copy to clipboard).
  /// Future: use file_picker / share_plus to save file; for now show a placeholder.
  void _exportKeys() {
    // TODO: Show dialog to enter password, then call _syncService.exportEncryptedKeys(password),
    // then save to file or copy base64 to clipboard.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export keys: enter password in dialog (coming soon)')),
    );
  }

  /// Import: pick file (or paste) → prompt password → importEncryptedKeys → keys restored to Hive.
  void _importKeys() {
    // TODO: Show file picker or paste field, then password dialog, then _syncService.importEncryptedKeys(data, password).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import keys: upload file and enter password (coming soon)')),
    );
  }

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
            const SizedBox(height: 24),
            // Key backup for multi-device: export/import conversation keys (password-encrypted).
            // UI flow: Export → user enters password → file downloads. Import → upload file → enter password → keys restored.
            const Text(
              'Conversation keys (multi-device)',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 1.0),
            ListTile(
              title: const Text('Export conversation keys'),
              subtitle: const Text('Save encrypted keys to a file for use on another device'),
              leading: const Icon(Icons.upload_file),
              onTap: _exportKeys,
            ),
            ListTile(
              title: const Text('Import conversation keys'),
              subtitle: const Text('Restore keys from a file (e.g. after switching device)'),
              leading: const Icon(Icons.download),
              onTap: _importKeys,
            ),
          ],
        ),
      ),
    );
  }
}