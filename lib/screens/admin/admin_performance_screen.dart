import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/response_time_analytics.dart';
import '../../provider/firestore_provider.dart';
import '../../services/reporting_service.dart';
import '../../widgets/admin_performance_card.dart';

/// Admin performance leaderboard and individual detail.
class AdminPerformanceScreen extends StatefulWidget {
  const AdminPerformanceScreen({
    super.key,
    this.initialStart,
    this.initialEnd,
  });

  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  State<AdminPerformanceScreen> createState() => _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState extends State<AdminPerformanceScreen> {
  late ReportingService _reportingService;
  DateTime _startDate;
  DateTime _endDate;
  List<AdminPerformance> _list = [];
  bool _loading = true;
  String? _error;

  _AdminPerformanceScreenState()
      : _startDate = DateTime.now().subtract(const Duration(days: 7)),
        _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialStart != null) _startDate = widget.initialStart!;
    if (widget.initialEnd != null) _endDate = widget.initialEnd!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportingService = ReportingService(
        firestore: context.read<FirestoreProvider>().firestore,
      );
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final organizationId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    try {
      final list = await _reportingService.getAdminPerformance(
        organizationId: organizationId,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  int get _periodDays => _endDate.difference(_startDate).inDays.clamp(1, 365);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('dd.MM', 'de');
    final dateRangeText =
        '${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminPerformance),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: l10n.forceRefresh,
          ),
        ],
      ),
      body: _loading && _list.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(l10n)
              : _list.isEmpty
                  ? _buildEmpty(l10n)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              dateRangeText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            if (_list.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.emoji_events,
                                      color: Colors.amber.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.topPerformer,
                                      style:
                                          Theme.of(context).textTheme.titleSmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _list.first.adminName.isNotEmpty
                                            ? _list.first.adminName
                                            : _list.first.adminId,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ..._list.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AdminPerformanceCard(
                                  performance: p,
                                  periodDays: _periodDays,
                                  onTap: () => _openDetail(p),
                                ),
                              ),
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.errorLoading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.leaderboard,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Keine Admin-Aktivität im gewählten Zeitraum.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openDetail(AdminPerformance performance) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _AdminPerformanceDetailScreen(
          performance: performance,
          periodDays: _periodDays,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
  }
}

/// Detail view for a single admin's performance.
class _AdminPerformanceDetailScreen extends StatelessWidget {
  const _AdminPerformanceDetailScreen({
    required this.performance,
    required this.periodDays,
    required this.startDate,
    required this.endDate,
  });

  final AdminPerformance performance;
  final int periodDays;
  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy', 'de');
    final messagesPerDay = periodDays > 0
        ? (performance.messagesSent / periodDays).toStringAsFixed(1)
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: Text(performance.adminName.isNotEmpty
            ? performance.adminName
            : performance.adminId),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (performance.rank != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Text(
                      '${l10n.rank}: ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${performance.rank}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            _detailRow(context, l10n.conversationsHandled, '${performance.conversationsHandled}'),
            _detailRow(context, l10n.messagesSent, '${performance.messagesSent}'),
            _detailRow(context, l10n.messagesPerDay, messagesPerDay),
            _detailRow(context, l10n.averageResponseTime,
                ResponseTimeAnalytics.formatDurationGerman(performance.averageResponseTime)),
            if (performance.averageFirstResponseTime != null)
              _detailRow(
                context,
                l10n.averageFirstResponse,
                ResponseTimeAnalytics.formatDurationGerman(
                    performance.averageFirstResponseTime!),
              ),
            if (performance.lastActive != null)
              _detailRow(
                context,
                'Zuletzt aktiv',
                dateFormat.format(performance.lastActive!),
              ),
            if (performance.conversationCompletionRate != null)
              _detailRow(
                context,
                'Abschlussquote',
                '${performance.conversationCompletionRate!.toStringAsFixed(0)} %',
              ),
            const SizedBox(height: 24),
            Text(
              'Gesprächsliste für diesen Admin kann später ergänzt werden.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
