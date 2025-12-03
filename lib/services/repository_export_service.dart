import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:js_interop' show JSArray;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web/web.dart' as web;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:pdh/models/repository_goal.dart';

class RepositoryExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to create JSArray<BlobPart> from Uint8List
  static JSArray<web.BlobPart> _createBlobPartsArray(List<Uint8List> parts) {
    // Uint8List is automatically interop-able as BlobPart
    // Use JSArray constructor with list conversion
    // Note: This uses an unsafe cast but is necessary for web interop
    // ignore: invalid_runtime_check_with_js_interop_types
    return parts as JSArray<web.BlobPart>;
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
  static Future<String?> _getManagerDepartment() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _firestore.collection('users').doc(uid).get();
      return (doc.data() ?? const {})['department'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchVerifiedAuditEntriesForDept({
    String? department,
    String? search,
    String? monthFilter, // YYYY-MM
    double? minScore,
    int limit = 1000,
  }) async {
    final dept = department ?? await _getManagerDepartment();
    if (dept == null || dept.isEmpty) return [];

    Query query = _firestore
        .collection('audit_entries')
        .where('userDepartment', isEqualTo: dept)
        .where('status', isEqualTo: 'verified')
        .orderBy('submittedDate', descending: true)
        .limit(limit);

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
      final items = await _fetchVerifiedAuditEntriesForDept(
        department: department,
        search: search,
        monthFilter: monthFilter,
        minScore: minScore,
      );

      final buffer = StringBuffer();
      buffer.writeln(
        'userId,userDisplayName,userDepartment,goalId,goalTitle,completedDate,submittedDate,score,acknowledgedBy,evidenceCount,comments',
      );

      for (final m in items) {
        final completed =
            (m['completedDate'] as Timestamp?)?.toDate().toIso8601String() ??
            '';
        final submitted =
            (m['submittedDate'] as Timestamp?)?.toDate().toIso8601String() ??
            '';
        final title = (m['goalTitle'] ?? '').toString().replaceAll(',', ' ');
        final comments = (m['comments'] ?? '').toString().replaceAll(',', ' ');
        final evidence = (m['evidence'] as List<dynamic>? ?? []);
        buffer.writeln(
          [
            m['userId'] ?? '',
            (m['userDisplayName'] ?? '').toString().replaceAll(',', ' '),
            (m['userDepartment'] ?? '').toString().replaceAll(',', ' '),
            m['goalId'] ?? '',
            title,
            completed,
            submitted,
            (m['score'] as num?)?.toStringAsFixed(2) ?? '',
            m['acknowledgedBy'] ?? '',
            evidence.length.toString(),
            comments,
          ].join(','),
        );
      }

      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'evidence_verified_${DateTime.now().millisecondsSinceEpoch}.csv';
      final blobParts = _createBlobPartsArray([bytes]);
      final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'text/csv'));
      final url = web.URL.createObjectURL(blob);
      // ignore: unused_local_variable
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..setAttribute('download', fileName)
        ..click();
      web.URL.revokeObjectURL(url);

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
      final items = await _fetchVerifiedAuditEntriesForDept(
        department: department,
        search: search,
        monthFilter: monthFilter,
        minScore: minScore,
      );

      final buffer = StringBuffer();
      buffer.writeln('Personal Development Hub – Verified Evidence Report');
      buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('');
      for (final m in items) {
        final completed = (m['completedDate'] as Timestamp?)?.toDate();
        buffer.writeln('- ${m['goalTitle'] ?? ''}');
        buffer.writeln(
          '  Employee: ${(m['userDisplayName'] ?? '')} (${(m['userDepartment'] ?? '')})',
        );
        buffer.writeln('  Goal ID: ${(m['goalId'] ?? '')}');
        buffer.writeln('  Completed: ${completed?.toIso8601String() ?? ''}');
        buffer.writeln(
          '  Score: ${(m['score'] as num?)?.toStringAsFixed(1) ?? '-'}',
        );
        buffer.writeln('  Verified by: ${(m['acknowledgedBy'] ?? '-')}');
        final evidence = (m['evidence'] as List<dynamic>? ?? []);
        buffer.writeln('  Evidence count: ${evidence.length}');
        buffer.writeln('');
      }

      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'evidence_verified_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final blob = web.Blob(
        _createBlobPartsArray([bytes]),
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final url = web.URL.createObjectURL(blob);
      // ignore: unused_local_variable
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..setAttribute('download', fileName)
        ..click();
      web.URL.revokeObjectURL(url);

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
      // Header
      buffer.writeln(
        'goalId,goalTitle,completedDate,verifiedDate,score,managerAcknowledgedBy,evidenceCount,comments',
      );
      for (final g in goals) {
        final completed = g.completedDate != null
            ? g.completedDate!.toIso8601String()
            : '';
        final verified = g.verifiedDate != null
            ? g.verifiedDate!.toIso8601String()
            : '';
        final safeTitle = g.goalTitle.replaceAll(',', ' ');
        final safeComments = (g.comments ?? '').replaceAll(',', ' ');
        buffer.writeln(
          [
            g.goalId,
            safeTitle,
            completed,
            verified,
            g.score?.toStringAsFixed(2) ?? '',
            g.managerAcknowledgedBy ?? '',
            g.evidence.length.toString(),
            safeComments,
          ].join(','),
        );
      }

      // Direct download instead of Firebase Storage
      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'repository_${DateTime.now().millisecondsSinceEpoch}.csv';
      final blob = web.Blob(
        _createBlobPartsArray([bytes]),
        web.BlobPropertyBag(type: 'text/csv'),
      );
      final url = web.URL.createObjectURL(blob);
      // ignore: unused_local_variable
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..setAttribute('download', fileName)
        ..click();
      web.URL.revokeObjectURL(url);

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
        'userId,userDisplayName,userDepartment,goalId,goalTitle,completedDate,verifiedDate,score,managerAcknowledgedBy,evidenceCount,comments',
      );
      for (final g in goals) {
        final completed = g.completedDate?.toIso8601String() ?? '';
        final verified = g.verifiedDate?.toIso8601String() ?? '';
        final safeTitle = g.goalTitle.replaceAll(',', ' ');
        final safeComments = (g.comments ?? '').replaceAll(',', ' ');
        buffer.writeln(
          [
            g.userId,
            g.userDisplayName.replaceAll(',', ' '),
            g.userDepartment.replaceAll(',', ' '),
            g.goalId,
            safeTitle,
            completed,
            verified,
            g.score?.toStringAsFixed(2) ?? '',
            g.managerAcknowledgedBy ?? '',
            g.evidence.length.toString(),
            safeComments,
          ].join(','),
        );
      }

      // Direct download instead of Firebase Storage
      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'repository_all_${DateTime.now().millisecondsSinceEpoch}.csv';
      final blob = web.Blob(
        _createBlobPartsArray([bytes]),
        web.BlobPropertyBag(type: 'text/csv'),
      );
      final url = web.URL.createObjectURL(blob);
      // ignore: unused_local_variable
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..setAttribute('download', fileName)
        ..click();
      web.URL.revokeObjectURL(url);

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

      final buffer = StringBuffer();
      buffer.writeln(
        'Personal Development Hub – Repository Export (All Users)',
      );
      buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('');
      for (final g in goals) {
        final date = g.completedDate ?? g.verifiedDate;
        buffer.writeln('- ${g.goalTitle}');
        buffer.writeln('  User: ${g.userDisplayName} (${g.userDepartment})');
        buffer.writeln('  Goal ID: ${g.goalId}');
        buffer.writeln('  Date: ${date?.toIso8601String() ?? ''}');
        buffer.writeln('  Score: ${g.score?.toStringAsFixed(1) ?? '-'}');
        buffer.writeln('  Manager: ${g.managerAcknowledgedBy ?? '-'}');
        buffer.writeln('  Evidence (${g.evidence.length})');
        buffer.writeln('');
      }

      // Direct download instead of Firebase Storage
      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'repository_all_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final blob = web.Blob(
        _createBlobPartsArray([bytes]),
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final url = web.URL.createObjectURL(blob);
      // ignore: unused_local_variable
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..setAttribute('download', fileName)
        ..click();
      web.URL.revokeObjectURL(url);

      developer.log('PDF export (all) downloaded: $fileName');
    } catch (e) {
      developer.log('Error exporting all repositories PDF: $e');
      rethrow;
    }
  }

  static Future<void> exportRepositoryAsPDF(String userId) async {
    try {
      // Lightweight text-based report (placeholder for PDF engine)
      final goals = await _fetchGoals(userId);
      final buffer = StringBuffer();
      buffer.writeln('Personal Development Hub – Repository Export');
      buffer.writeln('User: $userId');
      buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('');
      for (final g in goals) {
        final date = g.completedDate ?? g.verifiedDate;
        buffer.writeln('- ${g.goalTitle}');
        buffer.writeln('  Goal ID: ${g.goalId}');
        buffer.writeln('  Date: ${date?.toIso8601String() ?? ''}');
        buffer.writeln('  Score: ${g.score?.toStringAsFixed(1) ?? '-'}');
        buffer.writeln('  Manager: ${g.managerAcknowledgedBy ?? '-'}');
        buffer.writeln('  Evidence (${g.evidence.length}):');
        for (final e in g.evidence) {
          buffer.writeln('    • $e');
        }
        buffer.writeln('');
      }

      // Direct download instead of Firebase Storage
      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'repository_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final blob = web.Blob(
        _createBlobPartsArray([bytes]),
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final url = web.URL.createObjectURL(blob);
      // ignore: unused_local_variable
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..setAttribute('download', fileName)
        ..click();
      web.URL.revokeObjectURL(url);

      developer.log('PDF export downloaded: $fileName');
    } catch (e) {
      developer.log('Error exporting repository PDF: $e');
      rethrow;
    }
  }
}
