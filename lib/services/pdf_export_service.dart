import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/message_statistics.dart';
import '../models/response_time_analytics.dart';

/// Generates and shares/prints PDF reports for AnonCast statistics.
class PdfExportService {
  /// Builds a statistics report PDF and returns it as bytes.
  /// [organizationName] is shown in the header (e.g. admin name or org identifier).
  Future<Uint8List> exportStatisticsReport({
    required MessageStatistics stats,
    required ResponseTimeAnalytics responseTime,
    required String organizationName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd.MM.yyyy', 'de');
    final dateRangeStr =
        '${dateFormat.format(startDate)} – ${dateFormat.format(endDate)}';
    final createdStr = DateFormat('dd.MM.yyyy HH:mm', 'de').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            'AnonCast - Statistikbericht',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Erstellt von AnonCast · $createdStr',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Seite ${context.pageNumber} von ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (context) => [
          _buildHeader(organizationName, dateRangeStr),
          pw.SizedBox(height: 20),
          _buildStatsTable(stats),
          pw.SizedBox(height: 16),
          _buildStatusBreakdownTable(stats),
          pw.SizedBox(height: 16),
          _buildResponseTimeSection(responseTime),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String organizationName, String dateRangeStr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'AnonCast - Statistikbericht',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Organisation: $organizationName',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Zeitraum: $dateRangeStr',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
      ],
    );
  }

  pw.Widget _buildStatsTable(MessageStatistics stats) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        _tableRow('Gesamtnachrichten', '${stats.totalMessageCount}', isHeader: true),
        _tableRow('Aktive Gespräche', '${stats.activeConversationCount}'),
        _tableRow('Ungelesene Nachrichten', '${stats.unreadMessageCount}'),
        _tableRow(
          'Durchschnitt pro Tag',
          stats.averageMessagesPerDay.toStringAsFixed(1),
        ),
      ],
    );
  }

  pw.Widget _buildStatusBreakdownTable(MessageStatistics stats) {
    final statusLabels = <String, String>{
      'unread': 'Ungelesen',
      'read': 'Gelesen',
      'resolved': 'Erledigt',
    };
    final rows = <pw.TableRow>[
      _tableRow('Status', 'Anzahl', isHeader: true),
    ];
    for (final e in stats.messagesByStatus.entries) {
      rows.add(_tableRow(
        statusLabels[e.key] ?? e.key,
        '${e.value}',
      ));
    }
    if (stats.messagesByStatus.isEmpty) {
      rows.add(_tableRow('—', '—'));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  pw.TableRow _tableRow(String label, String value, {bool isHeader = false}) {
    return pw.TableRow(
      decoration: isHeader
          ? const pw.BoxDecoration(color: PdfColors.grey300)
          : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildResponseTimeSection(ResponseTimeAnalytics responseTime) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Antwortzeiten',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            _tableRow('Erste Antwortzeit', responseTime.averageFirstResponseTimeFormatted, isHeader: true),
            _tableRow(
              'Durchschnittliche Antwortzeit',
              responseTime.averageResponseTimeOverallFormatted,
            ),
            _tableRow(
              'Antwortquote',
              '${responseTime.responseRatePercent.toStringAsFixed(0)} %',
            ),
          ],
        ),
      ],
    );
  }

  /// Opens the system print/share dialog for the given PDF.
  /// [filename] is used when saving (e.g. "anoncast_bericht_2025-02-08.pdf").
  Future<void> shareOrPrintPDF(Uint8List pdfData, String filename) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
      name: filename,
    );
  }
}
