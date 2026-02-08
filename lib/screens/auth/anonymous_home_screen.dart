import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../models/user_role.dart';
import '../../provider/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../chat_screen.dart';

/// Shown when the user is already signed in anonymously (e.g. app restarted).
/// They enter their access code again to open their chat session.
class AnonymousHomeScreen extends StatefulWidget {
  const AnonymousHomeScreen({super.key});

  @override
  State<AnonymousHomeScreen> createState() => _AnonymousHomeScreenState();
}

class _AnonymousHomeScreenState extends State<AnonymousHomeScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.tabAnonymous,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.locale.languageCode == 'de'
                    ? 'Gib deinen Zugangscode ein, um zur Unterhaltung zu gelangen.'
                    : 'Enter your access code to continue to your conversation.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.accessCode,
                  hintText: 'XXXXXX',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.authErrorMessage('auth_error_code_required');
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _continue,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.continueToChat),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final l10n = AppLocalizations.of(context);
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final adminId = await auth.getAdminIdForValidCode(_codeController.text.trim());
      if (!mounted) return;
      if (adminId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.authErrorMessage('auth_error_code_invalid');
        });
        return;
      }

      _setOrCreateHiveUserInProvider(uid);
      final session = await chatService.getExistingOrNewChatByAdminId(uid, adminId);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (session != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(chatSession: session),
          ),
        );
      } else {
        setState(() {
          _errorMessage = l10n.authErrorMessage('auth_error_code_invalid');
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.authErrorMessage('auth_error_unknown');
      });
    }
  }

  void _setOrCreateHiveUserInProvider(String uid) {
    final userProvider = context.read<UserProvider>();
    final userBox = Hive.box<User>('users');
    final existing = userBox.get(uid);
    if (existing == null) {
      final u = User(id: uid, name: 'Anonymous', role: UserRole.student);
      userBox.put(uid, u);
      userProvider.setUser(u);
    } else {
      userProvider.setUser(existing);
    }
  }
}
