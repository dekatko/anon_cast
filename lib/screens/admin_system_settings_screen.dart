import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/security_report.dart';
import '../services/security_validator.dart';
import '../services/sync_service.dart';
import 'admin/admin_security_audit_screen.dart';

enum ConnectionType { wifiDirect, externalServer, localServer }

class AdministratorSystemSettingsScreen extends StatefulWidget {
  const AdministratorSystemSettingsScreen({super.key});

  @override
  AdministratorSystemSettingsScreenState createState() => AdministratorSystemSettingsScreenState();
}

class AdministratorSystemSettingsScreenState extends State<AdministratorSystemSettingsScreen> {
  ConnectionType _selectedConnectionType = ConnectionType.wifiDirect; // Initial selection
  final SyncService _syncService = SyncService();
  final SecurityValidator _securityValidator = SecurityValidator();
  SecurityReport? _lastSecurityReport;
  bool _auditRunning = false;

  /// Export: prompt password → exportEncryptedKeys → offer file download (or copy to clipboard).
  /// Future: use file_picker / share_plus to save file; for now show a placeholder.
  void _exportKeys() {
    // TODO: Show dialog to enter password, then call _syncService.exportEncryptedKeys(password),
    // then save to file or copy base64 to clipboard.
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.exportKeysComingSoon)),
    );
  }

  /// Import: pick file (or paste) → prompt password → importEncryptedKeys → keys restored to Hive.
  void _importKeys() {
    // TODO: Show file picker or paste field, then password dialog, then _syncService.importEncryptedKeys(data, password).
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importKeysComingSoon)),
    );
  }

  Future<void> _runSecurityAudit() async {
    if (_auditRunning) return;
    setState(() => _auditRunning = true);
    try {
      final report = await _securityValidator.runSecurityAudit();
      if (mounted) {
        setState(() {
          _lastSecurityReport = report;
          _auditRunning = false;
        });
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => AdminSecurityAuditScreen(
              report: report,
              onRunAgain: _runSecurityAudit,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _auditRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).auditFailed.replaceAll('%s', e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.systemSettingsTitle),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Settings Section
            Text(
              l10n.connectionSettingsTitle,
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 1.0),
            ListTile(
              title: Text(l10n.wifiDirect),
              trailing: Radio<ConnectionType>(
                value: ConnectionType.wifiDirect,
                groupValue: _selectedConnectionType,
                onChanged: (value) => setState(() => _selectedConnectionType = value!),
              ),
            ),
            ListTile(
              title: Text(l10n.externalServer),
              trailing: Radio<ConnectionType>(
                value: ConnectionType.externalServer,
                groupValue: _selectedConnectionType,
                onChanged: (value) => setState(() => _selectedConnectionType = value!),
              ),
            ),
            ListTile(
              title: Text(l10n.localServer),
              trailing: Radio<ConnectionType>(
                value: ConnectionType.localServer,
                groupValue: _selectedConnectionType,
                onChanged: (value) => setState(() => _selectedConnectionType = value!),
              ),
            ),
            const SizedBox(height: 24),
            // Security audit: validate encryption, keys not in Firestore, decryption integrity.
            Text(
              l10n.securityAuditSectionTitle,
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 1.0),
            ListTile(
              title: Text(l10n.runSecurityAudit),
              subtitle: Text(
                _lastSecurityReport == null
                    ? l10n.verifyEncryptionAndKeyStorage
                    : 'Last run: ${DateFormat.yMd().add_Hm().format(_lastSecurityReport!.timestamp)} — '
                        '${_lastSecurityReport!.allPassed ? "Passed" : "Failed"}',
              ),
              leading: Icon(
                _lastSecurityReport?.allPassed == true
                    ? Icons.security
                    : _lastSecurityReport != null
                        ? Icons.warning_amber
                        : Icons.verified_user,
                color: _lastSecurityReport?.allPassed == true
                    ? Colors.green
                    : _lastSecurityReport != null
                        ? Colors.orange
                        : null,
              ),
              trailing: _auditRunning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: _runSecurityAudit,
                      tooltip: l10n.runAuditTooltip,
                    ),
              onTap: _auditRunning ? null : _runSecurityAudit,
            ),
            if (_lastSecurityReport != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: OutlinedButton.icon(
                  onPressed: _auditRunning ? null : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => AdminSecurityAuditScreen(
                        report: _lastSecurityReport!,
                        onRunAgain: _runSecurityAudit,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.list),
                  label: Text(l10n.viewLastReport),
                ),
              ),
            const SizedBox(height: 24),
            // Key backup for multi-device: export/import conversation keys (password-encrypted).
            // UI flow: Export → user enters password → file downloads. Import → upload file → enter password → keys restored.
            Text(
              l10n.conversationKeysSectionTitle,
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 1.0),
            ListTile(
              title: Text(l10n.exportConversationKeys),
              subtitle: Text(l10n.exportConversationKeysSubtitle),
              leading: const Icon(Icons.upload_file),
              onTap: _exportKeys,
            ),
            ListTile(
              title: Text(l10n.importConversationKeys),
              subtitle: Text(l10n.importConversationKeysSubtitle),
              leading: const Icon(Icons.download),
              onTap: _importKeys,
            ),
          ],
        ),
      ),
    );
  }
}