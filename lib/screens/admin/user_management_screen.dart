import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/access_code.dart';
import '../../provider/access_codes_provider.dart';
import '../../provider/firestore_provider.dart';

/// Admin screen for managing access codes and viewing active user statistics.
class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AccessCodesProvider>(
      create: (context) => AccessCodesProvider(
        firestore: context.read<FirestoreProvider>().firestore,
      ),
      child: const _UserManagementBody(),
    );
  }
}

class _UserManagementBody extends StatefulWidget {
  const _UserManagementBody();

  @override
  State<_UserManagementBody> createState() => _UserManagementBodyState();
}

class _UserManagementBodyState extends State<_UserManagementBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccessCodesProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width > 700;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userManagementTitle),
        actions: [
          Consumer<AccessCodesProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.startListening(),
                tooltip: l10n.retry,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<AccessCodesProvider>().startListening();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 16,
            vertical: 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ActiveUsersSection(),
                  const SizedBox(height: 24),
                  _CodesToolbar(locale: locale),
                  const SizedBox(height: 12),
                  const _CodesList(),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGenerateDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.generateNewCode),
      ),
    );
  }

  void _openGenerateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _GenerateCodeDialog(screenContext: context),
    );
  }
}

class _ActiveUsersSection extends StatelessWidget {
  const _ActiveUsersSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Consumer<AccessCodesProvider>(
      builder: (context, provider, _) {
        final s = provider.activeStats;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.activeUsers,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isRow = constraints.maxWidth > 400;
                    final children = [
                      _StatChip(
                        label: l10n.totalAnonymousUsers,
                        value: '${s.totalAnonymousUsers}',
                      ),
                      _StatChip(
                        label: l10n.messagesLast24h,
                        value: '${s.messagesLast24h}',
                      ),
                      _StatChip(
                        label: l10n.messagesLast7d,
                        value: '${s.messagesLast7d}',
                      ),
                    ];
                    if (isRow) {
                      return Row(
                        children:
                            children.map((c) => Expanded(child: c)).toList(),
                      );
                    }
                    return Column(
                      children: children,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodesToolbar extends StatelessWidget {
  const _CodesToolbar({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AccessCodesProvider>();

    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: provider.setSearchQuery,
            decoration: InputDecoration(
              hintText: l10n.searchCodes,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<AccessCodeStatus?>(
          value: provider.filterStatus,
          hint: Text(l10n.filterByStatus),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
            DropdownMenuItem(
              value: AccessCodeStatus.active,
              child: Text(l10n.codeStatusActive),
            ),
            DropdownMenuItem(
              value: AccessCodeStatus.used,
              child: Text(l10n.codeStatusUsed),
            ),
            DropdownMenuItem(
              value: AccessCodeStatus.expired,
              child: Text(l10n.codeStatusExpired),
            ),
            DropdownMenuItem(
              value: AccessCodeStatus.revoked,
              child: Text(l10n.codeStatusRevoked),
            ),
          ],
          onChanged: provider.setFilterStatus,
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () =>
              _exportCsvToClipboard(context, provider.filteredCodes),
          icon: const Icon(Icons.download),
          label: Text(l10n.exportCsv),
        ),
      ],
    );
  }
}

void _exportCsvToClipboard(BuildContext context, List<AccessCode> codes) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).languageCode;
  final dateFormat = DateFormat.yMd(locale == 'de' ? 'de_DE' : 'en_US');
  final sb = StringBuffer();
  sb.writeln('Code,Status,Created,Expires,Single use,Used at,Revoked at');
  for (final c in codes) {
    sb.writeln([
      c.code,
      c.status.value,
      dateFormat.format(c.createdAt),
      dateFormat.format(c.expiresAt),
      c.singleUse ? 'Yes' : 'No',
      c.usedAt != null ? dateFormat.format(c.usedAt!) : '',
      c.revokedAt != null ? dateFormat.format(c.revokedAt!) : '',
    ].map((v) => '"${v.replaceAll('"', '""')}"').join(','));
  }
  Clipboard.setData(ClipboardData(text: sb.toString()));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
        content: Text(
            '${l10n.exportCsv}: ${codes.length} ${l10n.codeCopied.toLowerCase()}')),
  );
}

class _CodesList extends StatelessWidget {
  const _CodesList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final provider = context.watch<AccessCodesProvider>();
    final isWide = MediaQuery.sizeOf(context).width > 700;

    if (provider.hasError && provider.codes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(l10n.errorLoadingCodes, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => provider.startListening(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.isLoading && provider.codes.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      ));
    }

    final list = provider.filteredCodes;
    if (list.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.vpn_key_off,
                    size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(l10n.noCodes, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      );
    }

    if (isWide) {
      return Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(l10n.copyCode.split(' ').first)),
              DataColumn(label: Text(l10n.filterByStatus)),
              DataColumn(label: Text(l10n.expiryTime)),
              const DataColumn(label: Text('')),
            ],
            rows: list.map((code) => _codeToDataRow(context, code)).toList(),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _CodeCard(code: list[index]);
      },
    );
  }

  DataRow _codeToDataRow(BuildContext context, AccessCode code) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat.yMd(locale == 'de' ? 'de_DE' : 'en_US');
    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(code.code,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () =>
                    _copyAndSnackbar(context, code.code, l10n.codeCopied),
                tooltip: l10n.copyCode,
              ),
              IconButton(
                icon: const Icon(Icons.qr_code, size: 20),
                onPressed: () => _showQrDialog(context, code.code),
                tooltip: l10n.showQr,
              ),
            ],
          ),
        ),
        DataCell(_StatusBadge(status: code.status)),
        DataCell(Text(
            '${dateFormat.format(code.createdAt)} → ${dateFormat.format(code.expiresAt)}')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (code.isActive)
                TextButton(
                  onPressed: () => _confirmRevoke(context, code),
                  child: Text(l10n.revokeCode),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _confirmDelete(context, code),
                tooltip: l10n.deleteCode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _copyAndSnackbar(BuildContext context, String code, String message) {
  Clipboard.setData(ClipboardData(text: code));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _showQrDialog(BuildContext context, String code) {
  final l10n = AppLocalizations.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.showQr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: code,
            version: QrVersions.auto,
            size: 200,
          ),
          const SizedBox(height: 16),
          SelectableText(code, style: Theme.of(ctx).textTheme.titleMedium),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.codeCopied)));
            Navigator.pop(ctx);
          },
          child: Text(l10n.copyCode),
        ),
      ],
    ),
  );
}

Future<void> _confirmRevoke(BuildContext context, AccessCode code) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.revokeCode),
      content: Text(l10n.revokeConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.confirm),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    try {
      await context.read<AccessCodesProvider>().revokeCode(code.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.codeStatusRevoked)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorLoadingCodes)));
      }
    }
  }
}

Future<void> _confirmDelete(BuildContext context, AccessCode code) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteCode),
      content: Text(l10n.deleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.confirm),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    try {
      await context.read<AccessCodesProvider>().deleteCode(code.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.deleteCode)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorLoadingCodes)));
      }
    }
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final AccessCode code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat.yMd(locale == 'de' ? 'de_DE' : 'en_US');
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code.code,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                _StatusBadge(status: code.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dateFormat.format(code.createdAt)} → ${dateFormat.format(code.expiresAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (code.singleUse)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.singleUse,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () =>
                      _copyAndSnackbar(context, code.code, l10n.codeCopied),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.copyCode),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showQrDialog(context, code.code),
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: Text(l10n.showQr),
                ),
                if (code.isActive)
                  TextButton.icon(
                    onPressed: () => _confirmRevoke(context, code),
                    icon: const Icon(Icons.block, size: 18),
                    label: Text(l10n.revokeCode),
                  ),
                IconButton(
                  onPressed: () => _confirmDelete(context, code),
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  tooltip: l10n.deleteCode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AccessCodeStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String label;
    Color color;
    switch (status) {
      case AccessCodeStatus.active:
        label = l10n.codeStatusActive;
        color = theme.colorScheme.primary;
        break;
      case AccessCodeStatus.used:
        label = l10n.codeStatusUsed;
        color = theme.colorScheme.tertiary;
        break;
      case AccessCodeStatus.expired:
        label = l10n.codeStatusExpired;
        color = theme.colorScheme.error;
        break;
      case AccessCodeStatus.revoked:
        label = l10n.codeStatusRevoked;
        color = theme.colorScheme.outline;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _GenerateCodeDialog extends StatefulWidget {
  const _GenerateCodeDialog({required this.screenContext});

  final BuildContext screenContext;

  @override
  State<_GenerateCodeDialog> createState() => _GenerateCodeDialogState();
}

class _GenerateCodeDialogState extends State<_GenerateCodeDialog> {
  int _expiryDays = 7;
  bool _singleUse = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.generateNewCode),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.expiryTime,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _expiryDays,
                isExpanded: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [1, 3, 7, 14, 30]
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('$d ${l10n.days}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _expiryDays = v ?? 7),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(l10n.singleUse),
                value: _singleUse,
                onChanged: (v) => setState(() => _singleUse = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _generate(context),
          child: Text(l10n.generateNewCode),
        ),
      ],
    );
  }

  Future<void> _generate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final provider = widget.screenContext.read<AccessCodesProvider>();
    final adminId = FirebaseAuth.instance.currentUser?.uid;

    try {
      final code = await provider.createCode(
        expiryDays: _expiryDays,
        singleUse: _singleUse,
        adminId: adminId,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      _copyAndSnackbar(context, code.code, l10n.codeCopied);
      _showQrDialog(context, code.code);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorGenerate)),
        );
      }
    }
  }
}
