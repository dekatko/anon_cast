import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../models/user_role.dart';
import '../../provider/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../admin_dashboard_screen.dart';
import 'admin_login_screen.dart';
import '../chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  final _adminFormKey = GlobalKey<FormState>();
  final _anonymousFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Text(
                  l10n.loginTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.tabAdmin),
                  Tab(text: l10n.tabAnonymous),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AdminForm(
                      formKey: _adminFormKey,
                      emailController: _adminEmailController,
                      passwordController: _adminPasswordController,
                      isLoading: _isLoading,
                      errorMessage: _errorMessage,
                      onClearError: () => setState(() => _errorMessage = null),
                      onLogin: _loginAdmin,
                      onRegister: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AdministratorLoginScreen(),
                          ),
                        ).then((_) => _tabController.animateTo(0));
                      },
                    ),
                    _AnonymousForm(
                      formKey: _anonymousFormKey,
                      codeController: _codeController,
                      isLoading: _isLoading,
                      errorMessage: _errorMessage,
                      onClearError: () => setState(() => _errorMessage = null),
                      onContinue: _loginAnonymous,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginAdmin() async {
    if (!_adminFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final l10n = AppLocalizations.of(context);

    try {
      await auth.signInAdmin(
        _adminEmailController.text.trim(),
        _adminPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _navigateAdmin();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.authErrorMessage(e.messageKey);
      });
    }
  }

  Future<void> _loginAnonymous() async {
    if (!_anonymousFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final l10n = AppLocalizations.of(context);

    try {
      final result = await auth.signInAnonymous(_codeController.text.trim());
      if (!mounted) return;

      _setOrCreateHiveUserInProvider(context, result.user.uid);
      final session = await chatService.getExistingOrNewChatByAdminId(
        result.user.uid,
        result.adminId,
      );
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
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.authErrorMessage(e.messageKey);
      });
    }
  }

  void _navigateAdmin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const AdministratorDashboardScreen(),
      ),
    );
  }

  void _setOrCreateHiveUserInProvider(BuildContext context, String uid) {
    final userProvider = context.read<UserProvider>();
    final userBox = Hive.box<User>('users');
    final existing = userBox.get(uid);
    if (existing == null) {
      final u = User(
        id: uid,
        name: 'Anonymous',
        role: UserRole.student,
      );
      userBox.put(uid, u);
      userProvider.setUser(u);
    } else {
      userProvider.setUser(existing);
    }
  }
}

class _AdminForm extends StatelessWidget {
  const _AdminForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.errorMessage,
    required this.onClearError,
    required this.onLogin,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onClearError;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.email,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n.authErrorMessage('auth_error_email_required');
              }
              return null;
            },
            onTap: onClearError,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.password,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return l10n.authErrorMessage('auth_error_password_required');
              }
              return null;
            },
            onTap: onClearError,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : () => _showForgotPassword(context),
              child: Text(l10n.forgotPassword),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isLoading ? null : onLogin,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.login),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: isLoading ? null : onRegister,
            child: Text(l10n.administratorRegister),
          ),
        ],
      ),
    );
  }

  void _showForgotPassword(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthService>();
    final controller = TextEditingController(text: emailController.text);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.forgotPassword),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.email,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await auth.sendPasswordResetEmail(controller.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(ctx).locale.languageCode == 'de'
                            ? 'E-Mail zum Zurücksetzen gesendet.'
                            : 'Password reset email sent.',
                      ),
                    ),
                  );
                }
              } on AuthException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(ctx).authErrorMessage(e.messageKey),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.continueToChat),
          ),
        ],
      ),
    );
  }
}

class _AnonymousForm extends StatelessWidget {
  const _AnonymousForm({
    required this.formKey,
    required this.codeController,
    required this.isLoading,
    required this.errorMessage,
    required this.onClearError,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController codeController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onClearError;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
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
            onTap: onClearError,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isLoading ? null : onContinue,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.continueToChat),
          ),
        ],
      ),
    );
  }
}
