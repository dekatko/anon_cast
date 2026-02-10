import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/access_code.dart';
import '../../models/admin_message.dart';
import '../../models/comparative_statistics.dart';
import '../../models/message_statistics.dart';
import '../../models/response_time_analytics.dart';
import '../../models/security_report.dart';
import '../../provider/admin_messages_provider.dart';
import '../../provider/firestore_provider.dart';
import '../../services/access_code_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/reporting_service.dart';
import '../../services/security_validator.dart';
import '../../widgets/message_trend_chart.dart';
import '../../widgets/response_time_card.dart';
import '../../widgets/statistics_cards.dart';
import 'admin_performance_screen.dart';
import 'admin_security_audit_screen.dart';
import '../messages/message_thread_screen.dart';
import '../settings/settings_screen.dart';

/// Conversation summary for the dashboard list (derived from [AdminMessage]s + key rotation).
class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.displayName,
    this.lastMessagePreview,
    this.lastKeyRotation,
    this.unreadCount = 0,
  });

  final String conversationId;
  final String displayName;
  final String? lastMessagePreview;
  final DateTime? lastKeyRotation;
  final int unreadCount;
}

/// Admin dashboard: security status card, conversation list with encryption badges,
/// and quick actions (generate code, settings).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SecurityValidator _securityValidator = SecurityValidator();
  Future<SecurityReport>? _auditFuture;

  late final ReportingService _reportingService;
  Future<MessageStatistics>? _statisticsFuture;
  Future<ResponseTimeAnalytics>? _responseTimeFuture;
  Future<ComparativeStatistics>? _comparativeFuture;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  /// 'last7' | 'last30' | 'month' | null (custom).
  String? _periodPreset = 'last7';
  bool _isLoadingStats = false;
  bool _isExportingPdf = false;
  DateTime? _lastStatsUpdated;

  @override
  void initState() {
    super.initState();
    _auditFuture = _securityValidator.runSecurityAudit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportingService = ReportingService(
        firestore: context.read<FirestoreProvider>().firestore,
      );
      context.read<AdminMessagesProvider>().startListening(() {});
      _loadStatistics();
    });
  }

  Future<void> _loadStatistics({bool forceRefresh = false}) async {
    final organizationId =
        FirebaseAuth.instance.currentUser?.uid ?? 'default';
    setState(() => _isLoadingStats = true);
    final statsFuture = _reportingService.getMessageStatistics(
      organizationId: organizationId,
      startDate: _startDate,
      endDate: _endDate,
      bypassCache: forceRefresh,
    );
    final responseFuture = _reportingService.getResponseTimeAnalytics(
      organizationId: organizationId,
      startDate: _startDate,
      endDate: _endDate,
      bypassCache: forceRefresh,
    );
    final comparativeFuture = _reportingService.getComparativeStatistics(
      organizationId: organizationId,
      currentStart: _startDate,
      currentEnd: _endDate,
      bypassCache: forceRefresh,
    );
    setState(() {
      _statisticsFuture = statsFuture;
      _responseTimeFuture = responseFuture;
      _comparativeFuture = comparativeFuture;
    });
    try {
      await Future.wait([statsFuture, responseFuture, comparativeFuture]);
      if (mounted) setState(() => _lastStatsUpdated = DateTime.now());
    } catch (_) {
      // Futures already hold error; FutureBuilder will show it
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  void _applyPeriodPreset(int days) {
    final now = DateTime.now();
    setState(() {
      _endDate = now;
      _startDate = now.subtract(Duration(days: days));
      _periodPreset = days == 7 ? 'last7' : 'last30';
    });
    _loadStatistics();
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
      _periodPreset = 'month';
    });
    _loadStatistics();
  }

  bool _isPeriodPreset(int days) =>
      _periodPreset == (days == 7 ? 'last7' : 'last30');

  bool _isThisMonthSelected() => _periodPreset == 'month';

  Future<void> _pickDateRange(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: l10n.dateRangeLabel,
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _periodPreset = null;
      });
      await _loadStatistics();
    }
  }

  Future<void> _exportPdfReport(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (_statisticsFuture == null || _responseTimeFuture == null) return;
    setState(() => _isExportingPdf = true);
    try {
      final stats = await _statisticsFuture!;
      final responseTime = await _responseTimeFuture!;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      String organizationName = 'Unbekannt';
      if (uid != null && uid.isNotEmpty) {
        final admin = await context.read<FirestoreProvider>().getAdministrator(uid);
        if (admin != null) {
          organizationName = admin.name ?? admin.email;
        }
      }
      final pdfService = PdfExportService();
      final pdfData = await pdfService.exportStatisticsReport(
        stats: stats,
        responseTime: responseTime,
        organizationName: organizationName,
        startDate: _startDate,
        endDate: _endDate,
      );
      final filename =
          'anoncast_bericht_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      await pdfService.shareOrPrintPDF(pdfData, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.exportError}: $e'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width > 700;

    final dateFormat = DateFormat('dd.MM');
    final dateRangeText =
        '${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDashboardTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => AdminPerformanceScreen(
                  initialStart: _startDate,
                  initialEnd: _endDate,
                ),
              ),
            ),
            tooltip: l10n.leaderboard,
          ),
          if (_statisticsFuture != null)
            IconButton(
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _isExportingPdf ? null : () => _exportPdfReport(context),
              tooltip: l10n.exportPdfTooltip,
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
            tooltip: l10n.settingsLabel,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _auditFuture = _securityValidator.runSecurityAudit();
          });
          await _loadStatistics();
          if (mounted) context.read<AdminMessagesProvider>().refresh();
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
                  SecurityStatusCard(
                    auditFuture: _auditFuture!,
                    onRunAgain: () {
                      setState(() {
                        _auditFuture = _securityValidator.runSecurityAudit();
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // Period presets
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.last7Days),
                        selected: _isPeriodPreset(7),
                        onSelected: (_) => _applyPeriodPreset(7),
                      ),
                      FilterChip(
                        label: Text(l10n.last30Days),
                        selected: _isPeriodPreset(30),
                        onSelected: (_) => _applyPeriodPreset(30),
                      ),
                      FilterChip(
                        label: Text(l10n.thisMonth),
                        selected: _isThisMonthSelected(),
                        onSelected: (_) => _applyThisMonth(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date range selector and force refresh
                  Row(
                    children: [
                      Text(
                        l10n.dateRangeLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _isLoadingStats
                            ? null
                            : () => _pickDateRange(context),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(dateRangeText),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _isLoadingStats
                            ? null
                            : () => _loadStatistics(forceRefresh: true),
                        icon: const Icon(Icons.refresh),
                        tooltip: l10n.forceRefresh,
                      ),
                    ],
                  ),
                  if (_lastStatsUpdated != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.lastUpdatedMinutesAgo(
                        DateTime.now().difference(_lastStatsUpdated!).inMinutes.clamp(0, 999),
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildStatisticsSection(context, l10n),
                  const SizedBox(height: 24),
                  Text(
                    l10n.conversationsLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const _ConversationList(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateCodeDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.generateNewCode),
      ),
    );
  }

  Widget _buildStatisticsSection(
      BuildContext context, AppLocalizations l10n) {
    if (_statisticsFuture == null ||
        _responseTimeFuture == null ||
        _comparativeFuture == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _statisticsFuture!,
        _responseTimeFuture!,
        _comparativeFuture!,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.errorLoading,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadStatistics,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data!;
        final stats = data[0] as MessageStatistics;
        final responseAnalytics = data[1] as ResponseTimeAnalytics;
        final comparative = data[2] as ComparativeStatistics;
        final days = _endDate.difference(_startDate).inDays;
        final comparisonLabel = days <= 10
            ? l10n.vsLastWeek
            : (days <= 35 ? l10n.vsLastMonth : l10n.vsPreviousPeriod);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatisticsCards(
              statistics: stats,
              comparative: comparative,
              comparisonLabel: comparisonLabel,
            ),
            const SizedBox(height: 20),
            MessageTrendChart(dailyData: stats.dailyTrend),
            const SizedBox(height: 20),
            ResponseTimeCard(analytics: responseAnalytics),
            if (responseAnalytics.adminPerformanceList.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TopPerformerSummary(
                admins: responseAnalytics.adminPerformanceList,
                onTapLeaderboard: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => AdminPerformanceScreen(
                      initialStart: _startDate,
                      initialEnd: _endDate,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _showGenerateCodeDialog(BuildContext context) async {
    final code = await showDialog<AccessCodeData>(
      context: context,
      builder: (context) => _GenerateCodeDialog(
        firestore: context.read<FirestoreProvider>().firestore,
      ),
    );
    if (code != null && context.mounted) {
      _showCodeDisplay(context, code);
    }
  }

  void _showCodeDisplay(BuildContext context, AccessCodeData code) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat.yMd().add_Hm();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accessCodeGenerated),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: code.qrCodeData ?? code.code,
                version: QrVersions.auto,
                size: 200,
              ),
              const SizedBox(height: 16),
              SelectableText(
                code.code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('${l10n.expiresLabel}: ${dateFormat.format(code.expiresAt)}'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.copyCode),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.codeCopied)),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: Text(l10n.shareLabel),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '${l10n.codeCopied} ${l10n.shareLabel.toLowerCase()} manually.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}

/// Compact top-performer row with link to full leaderboard.
class _TopPerformerSummary extends StatelessWidget {
  const _TopPerformerSummary({
    required this.admins,
    required this.onTapLeaderboard,
  });

  final List<AdminPerformance> admins;
  final VoidCallback onTapLeaderboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = List<AdminPerformance>.from(admins)
      ..sort(AdminPerformance.compareByPerformance);
    final top = sorted.isNotEmpty ? sorted.first : null;
    if (top == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTapLeaderboard,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.topPerformer,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      top.adminName.isNotEmpty ? top.adminName : top.adminId,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                l10n.leaderboard,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Security status card with audit results and "View Details" → [AdminSecurityAuditScreen].
class SecurityStatusCard extends StatelessWidget {
  const SecurityStatusCard({
    super.key,
    required this.auditFuture,
    this.onRunAgain,
  });

  final Future<SecurityReport> auditFuture;
  final VoidCallback? onRunAgain;

  static bool _resultPassed(SecurityReport report, String name) {
    final list = report.results.where((e) => e.name == name).toList();
    return list.isNotEmpty && list.first.passed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<SecurityReport>(
      future: auditFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                    title: Text(l10n.securityCheckFailed),
                    subtitle: Text('${snapshot.error}'),
                  ),
                  if (onRunAgain != null)
                    TextButton(
                      onPressed: onRunAgain,
                      child: Text(l10n.retry),
                    ),
                ],
              ),
            ),
          );
        }

        final report = snapshot.data!;
        final summary =
            report.allPassed ? l10n.securityAllPassed : l10n.securitySomeFailed;
        final encryptionValid = _resultPassed(report, 'Message encryption');
        final keysSecure = _resultPassed(report, 'Local storage path');
        final noLeaks = _resultPassed(report, 'Keys not in Firestore');

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(
                  report.allPassed ? Icons.shield : Icons.warning,
                  color: report.allPassed ? Colors.green : Colors.orange,
                ),
                title: Text(l10n.securityStatus),
                subtitle: Text(summary),
              ),
              _buildStatusRow(context, l10n.messagesEncrypted, encryptionValid),
              _buildStatusRow(context, l10n.keysStoredLocally, keysSecure),
              _buildStatusRow(context, l10n.noDataLeaks, noLeaks),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: () => _showDetailedReport(context, report),
                  child: Text(l10n.viewDetails),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(BuildContext context, String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.error,
            size: 16,
            color: passed ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  void _showDetailedReport(BuildContext context, SecurityReport report) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AdminSecurityAuditScreen(
          report: report,
          onRunAgain: onRunAgain,
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminMessagesProvider>();

    if (provider.hasError) {
      final l10n = AppLocalizations.of(context);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(l10n.errorLoading),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => provider.refresh(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.isLoading && provider.allMessages.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final summaries = _buildSummaries(provider.allMessages);
    if (summaries.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.emptyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.emptySubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, DateTime>>(
      future: _loadLastKeyRotations(summaries.map((s) => s.conversationId).toList()),
      builder: (context, rotationSnapshot) {
        final rotations = rotationSnapshot.data ?? {};
        final list = summaries.map((s) {
          return ConversationSummary(
            conversationId: s.conversationId,
            displayName: s.displayName,
            lastMessagePreview: s.lastMessagePreview,
            lastKeyRotation: rotations[s.conversationId] ?? s.lastKeyRotation,
            unreadCount: s.unreadCount,
          );
        }).toList();

        return Column(
          children: list
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ConversationListItem(
                      conversation: c,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => MessageThreadScreen(
                            conversationId: c.conversationId,
                          ),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  static List<ConversationSummary> _buildSummaries(List<AdminMessage> messages) {
    final byConv = <String, List<AdminMessage>>{};
    for (final m in messages) {
      if (m.conversationId.isEmpty) continue;
      byConv.putIfAbsent(m.conversationId, () => []).add(m);
    }
    final list = <ConversationSummary>[];
    for (final e in byConv.entries) {
      final listMsgs = e.value;
      listMsgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final latest = listMsgs.first;
      final preview = latest.preview ?? (latest.encryptedContent.isNotEmpty ? '[Encrypted]' : null);
      final unread = listMsgs.where((m) => m.isUnread).length;
      final shortId = e.key.length > 8 ? e.key.substring(0, 8) : e.key;
      list.add(ConversationSummary(
        conversationId: e.key,
        displayName: 'Anonymous · $shortId',
        lastMessagePreview: preview,
        lastKeyRotation: null,
        unreadCount: unread,
      ));
    }
    list.sort((a, b) {
      final aMsgs = byConv[a.conversationId]!;
      final bMsgs = byConv[b.conversationId]!;
      final aLatest = aMsgs.first.timestamp;
      final bLatest = bMsgs.first.timestamp;
      return bLatest.compareTo(aLatest);
    });
    return list;
  }

  static Future<Map<String, DateTime>> _loadLastKeyRotations(
      List<String> conversationIds) async {
    final storage = LocalStorageService.instance;
    final map = <String, DateTime>{};
    for (final cid in conversationIds) {
      try {
        final ck = await storage.getConversationKeyFull(cid);
        if (ck != null) map[cid] = ck.lastRotated;
      } catch (_) {}
    }
    return map;
  }
}

class ConversationListItem extends StatelessWidget {
  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person_outline),
        ),
        title: Row(
          children: [
            Expanded(child: Text(conversation.displayName)),
            Icon(Icons.lock, size: 16, color: Colors.green),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation.lastMessagePreview ?? l10n.noMessagesYet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildKeyRotationBadge(context),
                const SizedBox(width: 8),
                if (conversation.lastKeyRotation != null)
                  Text(
                    l10n.keyRotatedDaysAgo(
                      DateTime.now().difference(conversation.lastKeyRotation!).inDays,
                    ),
                    style: caption,
                  ),
              ],
            ),
          ],
        ),
        trailing: conversation.unreadCount > 0
            ? CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.error,
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildKeyRotationBadge(BuildContext context) {
    final last = conversation.lastKeyRotation;
    if (last == null) return const SizedBox.shrink();
    final daysSinceRotation = DateTime.now().difference(last).inDays;
    if (daysSinceRotation <= 25) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Chip(
      label: Text(l10n.rotationDue, style: const TextStyle(fontSize: 10)),
      backgroundColor: Colors.orange.shade100,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Generate-code dialog: single use switch, expiry days, Cancel/Generate.
class _GenerateCodeDialog extends StatefulWidget {
  const _GenerateCodeDialog({required this.firestore});

  final dynamic firestore;

  @override
  State<_GenerateCodeDialog> createState() => _GenerateCodeDialogState();
}

class _GenerateCodeDialogState extends State<_GenerateCodeDialog> {
  bool _singleUse = false;
  int _expiryDays = 30;
  bool _loading = false;
  String? _error;
  late final TextEditingController _expiryController;

  @override
  void initState() {
    super.initState();
    _expiryController = TextEditingController(text: '30');
  }

  @override
  void dispose() {
    _expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.generateAccessCode),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(l10n.singleUse),
              value: _singleUse,
              onChanged: (v) => setState(() => _singleUse = v),
            ),
            TextField(
              decoration: InputDecoration(
                labelText: l10n.expiryDaysLabel,
              ),
              keyboardType: TextInputType.number,
              controller: _expiryController,
              onChanged: (v) {
                setState(() {
                  _expiryDays = int.tryParse(v) ?? 30;
                  if (_expiryDays > 30) _expiryDays = 30;
                  if (_expiryDays < 1) _expiryDays = 1;
                });
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _loading ? null : () => _generate(context),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.confirm),
        ),
      ],
    );
  }

  Future<void> _generate(BuildContext context) async {
    final auth = FirebaseAuth.instance;
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() => _error = 'You must be logged in to generate a code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = AccessCodeService(
        firestore: widget.firestore,
        auth: auth,
      );
      final code = await service.generateAccessCode(
        organizationId: 'default',
        adminUserId: uid,
        expiryDays: _expiryDays,
        singleUse: _singleUse,
      );
      if (context.mounted) Navigator.pop(context, code);
    } on AccessCodeServiceException catch (e) {
      if (context.mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }
}
