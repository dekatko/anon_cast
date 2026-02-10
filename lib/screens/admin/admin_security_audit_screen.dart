import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/security_report.dart';

/// Displays security audit results: validation checks, warnings, recommendations.
class AdminSecurityAuditScreen extends StatelessWidget {
  const AdminSecurityAuditScreen({
    super.key,
    required this.report,
    this.onRunAgain,
  });

  final SecurityReport report;
  final VoidCallback? onRunAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat.yMd().add_Hm();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.securityAuditTitle),
        actions: [
          if (onRunAgain != null)
            TextButton(
              onPressed: onRunAgain,
              child: Text(l10n.runAgain),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(report: report, dateFormat: dateFormat),
          const SizedBox(height: 16),
          const Text(
            'Checks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          ...report.results.map((r) => _ResultTile(result: r)),
          if (report.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Warnings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...report.warnings.map((w) => ListTile(
                  leading: const Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text(w),
                )),
          ],
          if (report.recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...report.recommendations.map((r) => ListTile(
                  leading: const Icon(Icons.lightbulb_outline, color: Colors.blue),
                  title: Text(r),
                )),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.report, required this.dateFormat});

  final SecurityReport report;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final passed = report.allPassed;
    return Card(
      color: passed ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  passed ? Icons.check_circle : Icons.error,
                  color: passed ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  passed ? 'All checks passed' : 'Some checks failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: passed ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${report.passedCount} passed, ${report.failedCount} failed',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Run at ${dateFormat.format(report.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final ValidationResult result;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        result.passed ? Icons.check_circle : Icons.cancel,
        color: result.passed ? Colors.green : Colors.red,
      ),
      title: Text(result.name),
      subtitle: result.message != null
          ? Text(result.message!)
          : (result.details != null ? Text(result.details!) : null),
    );
  }
}
