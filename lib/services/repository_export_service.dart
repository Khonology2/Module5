// ignore_for_file: avoid_web_libraries_in_flutter
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:developer' as developer;
// Web-only API for downloads (Flutter Web)
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pdh/models/repository_goal.dart';

class RepositoryExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Future<List<RepositoryGoal>> _fetchGoals(String userId) async {
    final snap = await _firestore
        .collection('repositories')
        .doc(userId)
        .collection('completedGoals')
        .orderBy('verifiedDate', descending: true)
        .get();
    return snap.docs.map((d) => RepositoryGoal.fromFirestore(d)).toList();
  }

  // -------------------- Manager Verified Audit Entries Export --------------------
  static Future<List<Map<String, dynamic>>> _fetchVerifiedAuditEntries({
    String? department,
    String? search,
    String? monthFilter, // YYYY-MM
    double? minScore,
    int limit = 1000,
  }) async {
    Query query = _firestore
        .collection('audit_entries')
        .where('status', isEqualTo: 'verified');

    if (department != null && department.isNotEmpty) {
      query = query.where('userDepartment', isEqualTo: department);
    }

    query = query.orderBy('submittedDate', descending: true).limit(limit);

    final snap = await query.get();
    var items = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    // Client-side filters to match UI
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      items = items.where((m) {
        final goalTitle = (m['goalTitle'] ?? '').toString().toLowerCase();
        final userName = (m['userDisplayName'] ?? '').toString().toLowerCase();
        final dept = (m['userDepartment'] ?? '').toString().toLowerCase();
        final evidence = (m['evidence'] as List<dynamic>? ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList();
        return goalTitle.contains(q) ||
            userName.contains(q) ||
            dept.contains(q) ||
            evidence.any((e) => e.contains(q));
      }).toList();
    }

    if (monthFilter != null && monthFilter.isNotEmpty) {
      items = items.where((m) {
        final ts = m['completedDate'] as Timestamp?;
        final d = ts?.toDate();
        if (d == null) return false;
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        return key == monthFilter;
      }).toList();
    }

    if (minScore != null) {
      items = items
          .where((m) => ((m['score'] as num?)?.toDouble() ?? 0) >= minScore)
          .toList();
    }

    return items;
  }

  static Future<void> exportManagerVerifiedAsCSV({
    String? department,
    String? search,
    String? monthFilter,
    double? minScore,
  }) async {
    try {
      final items = await _fetchVerifiedAuditEntries(
        department: department,
        search: search,
        monthFilter: monthFilter,
        minScore: minScore,
      );

      final buffer = StringBuffer();
      // Friendlier manager CSV: people & goal details first, IDs last
      buffer.writeln(
        'Employee Name,Department,Goal Title,Score (0-10),Completed Date,Submitted Date,Verified By,No. of Evidence Items,Manager Comments,Employee ID,Goal ID',
      );

      for (final m in items) {
        final completedDt = (m['completedDate'] as Timestamp?)?.toDate();
        final submittedDt = (m['submittedDate'] as Timestamp?)?.toDate();
        final completed = completedDt != null ? _formatDate(completedDt) : '';
        final submitted = submittedDt != null ? _formatDate(submittedDt) : '';
        final title = (m['goalTitle'] ?? '').toString().replaceAll(',', ' ');
        final comments = (m['comments'] ?? '').toString().replaceAll(',', ' ');
        final evidence = (m['evidence'] as List<dynamic>? ?? []);
        final employeeName = (m['userDisplayName'] ?? '').toString().replaceAll(
          ',',
          ' ',
        );
        final dept = (m['userDepartment'] ?? '').toString().replaceAll(
          ',',
          ' ',
        );
        final score = (m['score'] as num?)?.toStringAsFixed(1) ?? '';
        final verifiedBy = (m['acknowledgedBy'] ?? '').toString();
        final userId = (m['userId'] ?? '').toString();
        final goalId = (m['goalId'] ?? '').toString();

        buffer.writeln(
          [
            employeeName,
            dept,
            title,
            score,
            completed,
            submitted,
            verifiedBy,
            evidence.length.toString(),
            comments,
            userId,
            goalId,
          ].join(','),
        );
      }

      if (!kIsWeb) {
        throw UnsupportedError('CSV export is only supported on web');
      }
      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'evidence_verified_${DateTime.now().millisecondsSinceEpoch}.csv';
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      developer.log('Manager verified CSV export downloaded: $fileName');
    } catch (e) {
      developer.log('Error exporting manager verified CSV: $e');
      rethrow;
    }
  }

  static Future<void> exportManagerVerifiedAsPDF({
    String? department,
    String? search,
    String? monthFilter,
    double? minScore,
  }) async {
    try {
      final items = await _fetchVerifiedAuditEntries(
        department: department,
        search: search,
        monthFilter: monthFilter,
        minScore: minScore,
      );

      // Build a simple multi-page PDF report
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(24),
            pageFormat: PdfPageFormat.a4,
          ),
          build: (context) {
            final widgets = <pw.Widget>[];

            widgets.add(
              pw.Text(
                'Personal Development Hub – Verified Evidence Report',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(
              pw.Text(
                'Generated: ${DateTime.now().toIso8601String()}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));

            for (final m in items) {
              final completed = (m['completedDate'] as Timestamp?)?.toDate();
              final completedStr = completed != null
                  ? _formatDate(completed)
                  : '';
              final score = (m['score'] as num?)?.toStringAsFixed(1) ?? '-';
              final verifiedBy = (m['acknowledgedBy'] ?? '-').toString();
              final comments = (m['comments'] ?? '').toString();
              widgets.add(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      m['goalTitle']?.toString() ?? '',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Employee: ${(m['userDisplayName'] ?? '')} • Department: ${(m['userDepartment'] ?? '')}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Goal ID: ${(m['goalId'] ?? '')}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Completed: $completedStr',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Score: $score / 10',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Verified by: $verifiedBy',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (comments.trim().isNotEmpty)
                      pw.Text(
                        'Manager comments: $comments',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    pw.SizedBox(height: 8),
                  ],
                ),
              );
            }

            return widgets;
          },
        ),
      );

      if (!kIsWeb) {
        throw UnsupportedError('PDF export is only supported on web');
      }
      final bytes = await doc.save();
      final fileName =
          'evidence_verified_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..download = fileName
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      developer.log('Manager verified PDF export downloaded: $fileName');
    } catch (e) {
      developer.log('Error exporting manager verified PDF: $e');
      rethrow;
    }
  }

  static Future<void> exportRepositoryAsCSV(String userId) async {
    try {
      final goals = await _fetchGoals(userId);
      final buffer = StringBuffer();
      // Friendlier header for employee CSV: goal summary first
      buffer.writeln(
        'Goal Title,Score (0-10),Completed Date,Verified Date,Manager,No. of Evidence Items,Manager Comments,Goal ID',
      );
      for (final g in goals) {
        final completed = g.completedDate != null
            ? _formatDate(g.completedDate!)
            : '';
        final verified = g.verifiedDate != null
            ? _formatDate(g.verifiedDate!)
            : '';
        final safeTitle = g.goalTitle.replaceAll(',', ' ');
        final safeComments = (g.comments ?? '').replaceAll(',', ' ');
        final score = g.score?.toStringAsFixed(1) ?? '';
        final manager = (g.managerAcknowledgedBy ?? '').replaceAll(',', ' ');
        final evidenceCount = g.evidence.length.toString();

        buffer.writeln(
          [
            safeTitle,
            score,
            completed,
            verified,
            manager,
            evidenceCount,
            safeComments,
            g.goalId,
          ].join(','),
        );
      }

      // Direct download instead of Firebase Storage
      if (!kIsWeb) {
        throw UnsupportedError('CSV export is only supported on web');
      }
      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'repository_${DateTime.now().millisecondsSinceEpoch}.csv';
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..download = fileName
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      developer.log('CSV export downloaded: $fileName');
    } catch (e) {
      developer.log('Error exporting repository CSV: $e');
      rethrow;
    }
  }

  // Manager-wide CSV export (all users). Requires rules allowing collectionGroup reads and Storage writes.
  static Future<void> exportAllRepositoriesAsCSV() async {
    try {
      final snap = await _firestore
          .collectionGroup('completedGoals')
          .orderBy('verifiedDate', descending: true)
          .get();
      final goals = snap.docs
          .map((d) => RepositoryGoal.fromFirestore(d))
          .toList();

      final buffer = StringBuffer();
      buffer.writeln(
        'Employee Name,Department,Goal Title,Score (0-10),Completed Date,Verified Date,Manager,No. of Evidence Items,Manager Comments,Employee ID,Goal ID',
      );
      for (final g in goals) {
        final completed = g.completedDate != null
            ? _formatDate(g.completedDate!)
            : '';
        final verified = g.verifiedDate != null
            ? _formatDate(g.verifiedDate!)
            : '';
        final safeTitle = g.goalTitle.replaceAll(',', ' ');
        final safeComments = (g.comments ?? '').replaceAll(',', ' ');
        final employeeName = g.userDisplayName.replaceAll(',', ' ');
        final dept = g.userDepartment.replaceAll(',', ' ');
        final score = g.score?.toStringAsFixed(1) ?? '';
        final manager = (g.managerAcknowledgedBy ?? '').replaceAll(',', ' ');
        final evidenceCount = g.evidence.length.toString();

        buffer.writeln(
          [
            employeeName,
            dept,
            safeTitle,
            score,
            completed,
            verified,
            manager,
            evidenceCount,
            safeComments,
            g.userId,
            g.goalId,
          ].join(','),
        );
      }

      // Direct download instead of Firebase Storage
      if (!kIsWeb) {
        throw UnsupportedError('CSV export is only supported on web');
      }
      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'repository_all_${DateTime.now().millisecondsSinceEpoch}.csv';
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..download = fileName
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      developer.log('CSV export (all) downloaded: $fileName');
    } catch (e) {
      developer.log('Error exporting all repositories CSV: $e');
      rethrow;
    }
  }

  // Manager-wide PDF export (text report placeholder)
  static Future<void> exportAllRepositoriesAsPDF() async {
    try {
      final snap = await _firestore
          .collectionGroup('completedGoals')
          .orderBy('verifiedDate', descending: true)
          .get();
      final goals = snap.docs
          .map((d) => RepositoryGoal.fromFirestore(d))
          .toList();

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(24),
            pageFormat: PdfPageFormat.a4,
          ),
          build: (context) {
            final widgets = <pw.Widget>[];
            widgets.add(
              pw.Text(
                'Personal Development Hub – Repository Export (All Users)',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(
              pw.Text(
                'Generated: ${DateTime.now().toIso8601String()}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));

            for (final g in goals) {
              final date = g.completedDate ?? g.verifiedDate;
              final dateStr = date != null ? _formatDate(date) : '';
              final score = g.score?.toStringAsFixed(1) ?? '-';
              widgets.add(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      g.goalTitle,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'User: ${g.userDisplayName} • Department: ${g.userDepartment}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Goal ID: ${g.goalId}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Date: $dateStr',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Score: $score / 10',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Manager: ${g.managerAcknowledgedBy ?? '-'}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Evidence (${g.evidence.length})',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 8),
                  ],
                ),
              );
            }

            return widgets;
          },
        ),
      );

      // Direct download instead of Firebase Storage
      if (!kIsWeb) {
        throw UnsupportedError('PDF export is only supported on web');
      }
      final bytes = await doc.save();
      final fileName =
          'repository_all_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..download = fileName
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      developer.log('PDF export (all) downloaded: $fileName');
    } catch (e) {
      developer.log('Error exporting all repositories PDF: $e');
      rethrow;
    }
  }

  static Future<void> exportRepositoryAsPDF(String userId) async {
    try {
      final goals = await _fetchGoals(userId);
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(24),
            pageFormat: PdfPageFormat.a4,
          ),
          build: (context) {
            final widgets = <pw.Widget>[];
            widgets.add(
              pw.Text(
                'Personal Development Hub – Repository Export',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(
              pw.Text('User: $userId', style: const pw.TextStyle(fontSize: 10)),
            );
            widgets.add(
              pw.Text(
                'Generated: ${DateTime.now().toIso8601String()}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));

            for (final g in goals) {
              final date = g.completedDate ?? g.verifiedDate;
              final dateStr = date != null ? _formatDate(date) : '';
              final score = g.score?.toStringAsFixed(1) ?? '-';
              widgets.add(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      g.goalTitle,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Goal ID: ${g.goalId}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Date: $dateStr',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Score: $score / 10',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Manager: ${g.managerAcknowledgedBy ?? '-'}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (g.evidence.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Evidence (${g.evidence.length}):',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      for (final e in g.evidence)
                        pw.Bullet(
                          text: e,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                    pw.SizedBox(height: 8),
                  ],
                ),
              );
            }

            return widgets;
          },
        ),
      );

      // Direct download instead of Firebase Storage
      if (!kIsWeb) {
        throw UnsupportedError('PDF export is only supported on web');
      }
      final bytes = await doc.save();
      final fileName =
          'repository_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      developer.log('PDF export downloaded: $fileName');
    } catch (e) {
      developer.log('Error exporting repository PDF: $e');
      rethrow;
    }
  }
}
