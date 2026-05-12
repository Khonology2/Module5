import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Branded PDF blocks for admin portal data export (same chrome as settings PDF).
class AdminExportPdfWidgets {
  AdminExportPdfWidgets._();

  static void addManagersOverview({
    required List<pw.Widget> widgets,
    required pw.Font ttfFont,
    required PdfColor headerColor,
    required List<Map<String, dynamic>> portalManagers,
  }) {
    final totalManagers = portalManagers.length;
    final completedOrg = portalManagers.fold<int>(
      0,
      (s, m) => s + ((m['completedGoalsCount'] as num?)?.round() ?? 0),
    );
    final orgPoints = portalManagers.fold<int>(
      0,
      (s, m) => s + ((m['totalPoints'] as num?)?.round() ?? 0),
    );
    final atRiskCount = portalManagers
        .where((m) => (m['status'] as String?) == 'atRisk')
        .length;
    final avgProgressPct = totalManagers == 0
        ? 0.0
        : portalManagers
                  .map((m) => (m['avgProgress'] as num?)?.toDouble() ?? 0.0)
                  .reduce((a, b) => a + b) /
              totalManagers;

    widgets.add(
      pw.Header(
        level: 1,
        child: pw.Text(
          'Managers overview',
          style: pw.TextStyle(
            font: ttfFont,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: headerColor,
          ),
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 6));
    widgets.add(
      pw.Text(
        'Snapshot from the same source as the admin dashboard (monthly window).',
        style: pw.TextStyle(
          font: ttfFont,
          fontSize: 9,
          color: PdfColors.grey700,
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 8));

    widgets.add(
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  pw.Text(
                    totalManagers.toString(),
                    style: pw.TextStyle(
                      font: ttfFont,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Managers',
                    style: pw.TextStyle(
                      font: ttfFont,
                      color: PdfColors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  pw.Text(
                    completedOrg.toString(),
                    style: pw.TextStyle(
                      font: ttfFont,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Goals completed (period)',
                    style: pw.TextStyle(
                      font: ttfFont,
                      color: PdfColors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                children: [
                  pw.Text(
                    '${avgProgressPct.toStringAsFixed(0)}%',
                    style: pw.TextStyle(
                      font: ttfFont,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Avg manager progress',
                    style: pw.TextStyle(
                      font: ttfFont,
                      color: PdfColors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    widgets.add(pw.SizedBox(height: 8));
    widgets.add(
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Organization points: $orgPoints',
            style: pw.TextStyle(font: ttfFont, fontSize: 10),
          ),
          pw.Text(
            'At-risk managers: $atRiskCount',
            style: pw.TextStyle(font: ttfFont, fontSize: 10),
          ),
        ],
      ),
    );
    widgets.add(pw.SizedBox(height: 8));

    final byMgrStatus = <String, int>{};
    for (final m in portalManagers) {
      final k = (m['status'] as String?) ?? 'unknown';
      byMgrStatus[k] = (byMgrStatus[k] ?? 0) + 1;
    }
    if (byMgrStatus.isNotEmpty) {
      widgets.add(
        pw.Text(
          'Managers by status:',
          style: pw.TextStyle(
            font: ttfFont,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
      widgets.add(
        pw.Column(
          children: byMgrStatus.entries
              .map(
                (e) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      e.key,
                      style: pw.TextStyle(
                        font: ttfFont,
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      e.value.toString(),
                      style: pw.TextStyle(
                        font: ttfFont,
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }

    widgets.add(
      pw.Header(
        level: 1,
        child: pw.Text(
          'Managers directory',
          style: pw.TextStyle(
            font: ttfFont,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: headerColor,
          ),
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 6));
    if (portalManagers.isEmpty) {
      widgets.add(
        pw.Text(
          'No managers returned for this export.',
          style: pw.TextStyle(
            font: ttfFont,
            color: PdfColors.white,
            fontSize: 10,
          ),
        ),
      );
    } else {
      for (final m in portalManagers) {
        final name = (m['displayName'] ?? 'Unknown').toString();
        final dept = (m['department'] ?? '').toString();
        final st = (m['status'] ?? '').toString();
        final tp = (m['totalPoints'] ?? 0).toString();
        final cg = (m['completedGoalsCount'] ?? 0).toString();
        final ap = ((m['avgProgress'] as num?)?.toDouble() ?? 0.0)
            .toStringAsFixed(0);
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    font: ttfFont,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Department: ${dept.isEmpty ? '-' : dept} | Status: $st | '
                  'Points: $tp | Goals completed: $cg | Avg progress: $ap%',
                  style: pw.TextStyle(
                    font: ttfFont,
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }
}
