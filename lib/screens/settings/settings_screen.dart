import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../provider/firestore_provider.dart';
import '../../services/auth_service.dart';
import '../../services/conversation_key_rotation_service.dart';
import '../../services/encryption_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/message_relay.dart';
import '../../services/privacy_service.dart';
import '../../services/security_validator.dart';
import '../../services/sync_service.dart';
import '../admin/admin_security_audit_screen.dart';

/// Settings screen: privacy controls, key export/import, security audit, force key rotation.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SyncService _syncService = SyncService();
  final PrivacyService _privacyService = PrivacyService();
  final SecurityValidator _securityValidator = SecurityValidator();

  bool _autoClear = false;
  bool _autoClearLoading = true;
  bool _rotationRunning = false;
  bool _auditRunning = false;

  @override
  void initState() {
    super.initState();
    _loadAutoClearPref();
  }

  Future<void> _loadAutoClearPref() async {
    final value = await LocalStorageService.instance.getUserPref(AuthService.autoClearOnLogoutPrefKey);
    if (mounted) {
      setState(() {
        _autoClear = value == 'true';
        _autoClearLoading = false;
      });
    }
  }

  Future<void> _updateAutoClear(bool value) async {
    await LocalStorageService.instance.setUserPref(AuthService.autoClearOnLogoutPrefKey, value ? 'true' : 'false');
    if (mounted) setState(() => _autoClear = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsLabel),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 24 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(l10n.privacySectionTitle),
            Semantics(
              label: l10n.clearAllLocalData,
              child: ListTile(
                leading: const Icon(Icons.delete_forever),
                title: Text(l10n.clearAllLocalData),
                subtitle: Text(l10n.clearAllLocalDataSubtitle),
                onTap: _confirmClearData,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_delete),
              title: Text(l10n.autoClearOnLogout),
              subtitle: Text(l10n.autoClearOnLogoutSubtitle),
              trailing: _autoClearLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: _autoClear,
                      onChanged: _updateAutoClear,
                    ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(l10n.keyManagementSectionTitle),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: Text(l10n.exportEncryptionKeys),
              subtitle: Text(l10n.exportEncryptionKeysSubtitle),
              onTap: _exportKeys,
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: Text(l10n.importEncryptionKeys),
              subtitle: Text(l10n.importEncryptionKeysSubtitle),
              onTap: _importKeys,
            ),
            const SizedBox(height: 24),
            _sectionTitle(l10n.securitySectionTitle),
            ListTile(
              leading: _auditRunning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.security),
              title: Text(l10n.runSecurityAudit),
              subtitle: Text(l10n.runSecurityAuditSubtitle),
              onTap: _auditRunning ? null : _runSecurityAudit,
            ),
            ListTile(
              leading: _rotationRunning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              title: Text(l10n.forceKeyRotation),
              subtitle: Text(l10n.forceKeyRotationSubtitle),
              onTap: _rotationRunning ? null : _forceKeyRotation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Future<String?> _showPasswordDialog({
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => _PasswordDialog(
        title: title,
        message: message,
        controller: controller,
      ),
    );
  }

  Future<void> _confirmClearData() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.clearAllDataConfirmTitle),
        content: Text(l10n.clearAllDataConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.clearAllDataButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _privacyService.clearAllLocalData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.allLocalDataCleared)),
          );
        }
      } catch (e) {
        if (mounted) _showError('$e');
      }
    }
  }

  Future<void> _exportKeys() async {
    final l10n = AppLocalizations.of(context);
    final password = await _showPasswordDialog(
      title: l10n.protectYourKeys,
      message: l10n.protectYourKeysMessage,
    );
    if (password == null || password.isEmpty) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(l10n.exportingKeys),
          ],
        ),
      ),
    );

    try {
      final encryptedBackup = await _syncService.exportEncryptedKeys(password);
      if (!mounted) return;
      Navigator.pop(context);

      final bytes = Uint8List.fromList(utf8.encode(encryptedBackup));
      final fileName = 'anoncast_keys_backup_${DateTime.now().millisecondsSinceEpoch}.anonkey';
      final path = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
      );

      if (mounted) {
        if (path != null && path.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.keysExportedTo.replaceAll('%s', path))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.keysExportedTo.replaceAll('%s', fileName))),
          );
        }
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l10n.keepBackupSafe),
            content: Text(l10n.keepBackupSafeMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.iUnderstand),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError(l10n.exportFailed.replaceAll('%s', e.toString()));
      }
    }
  }

  Future<void> _importKeys() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['anonkey'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final fileBytes = file.bytes;
    if (fileBytes == null) {
      if (mounted) _showError(l10n.importFailed.replaceAll('%s', 'Could not read file bytes'));
      return;
    }

    final password = await _showPasswordDialog(
      title: l10n.enterBackupPassword,
      message: l10n.enterBackupPasswordMessage,
    );
    if (password == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(l10n.importingKeys),
          ],
        ),
      ),
    );

    try {
      final encryptedBackup = utf8.decode(fileBytes);
      final keyCount = await _syncService.importEncryptedKeys(encryptedBackup, password);
      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.importSuccessful),
          content: Text(l10n.importSuccessfulMessage.replaceAll('%s', '$keyCount')),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(l10n.goToDashboard),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError(
          '${l10n.importFailed.replaceAll('%s', e.toString())}\n\n${l10n.importFailedHint}',
        );
      }
    }
  }

  Future<void> _runSecurityAudit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _auditRunning = true);
    try {
      final report = await _securityValidator.runSecurityAudit();
      if (!mounted) return;
      setState(() => _auditRunning = false);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => AdminSecurityAuditScreen(
            report: report,
            onRunAgain: _runSecurityAudit,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _auditRunning = false);
        _showError('${l10n.securityCheckFailed}: $e');
      }
    }
  }

  Future<void> _forceKeyRotation() async {
    final l10n = AppLocalizations.of(context);
    ConversationKeyRotationService? rotationService;
    try {
      final firestore = context.read<FirestoreProvider>().firestore;
      rotationService = ConversationKeyRotationService(
        storage: LocalStorageService.instance,
        relay: FirestoreMessageRelay(firestore),
        encryption: EncryptionService(),
        firestore: firestore,
      );
    } catch (_) {
      if (mounted) _showError(l10n.rotationFailed.replaceAll('%s', 'Could not create rotation service'));
      return;
    }

    setState(() => _rotationRunning = true);
    try {
      final rotated = await rotationService.forceRotateAll();
      if (mounted) {
        setState(() => _rotationRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.rotationComplete.replaceAll('%s', '$rotated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _rotationRunning = false);
        _showError(l10n.rotationFailed.replaceAll('%s', e.toString()));
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

/// Password dialog with visibility toggle.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({
    required this.title,
    required this.message,
    required this.controller,
  });

  final String title;
  final String message;
  final TextEditingController controller;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, widget.controller.text),
          child: Text(l10n.continueLabel),
        ),
      ],
    );
  }
}
