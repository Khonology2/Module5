import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:pdh/models/repository_goal.dart';

class RepositoryExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<List<RepositoryGoal>> _fetchGoals(String userId) async {
    final snap = await _firestore
        .collection('repositories')
        .doc(userId)
        .collection('completedGoals')
        .orderBy('verifiedDate', descending: true)
        .get();
    return snap.docs.map((d) => RepositoryGoal.fromFirestore(d)).toList();
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

      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'repository_${DateTime.now().millisecondsSinceEpoch}.csv';
      final ref = _storage.ref().child('exports/$userId/$fileName');
      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'text/csv'),
      );
      final url = await ref.getDownloadURL();
      developer.log('CSV export uploaded: $url');
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
      final goals = snap.docs.map((d) => RepositoryGoal.fromFirestore(d)).toList();

      final buffer = StringBuffer();
      buffer.writeln(
        'userId,userDisplayName,userDepartment,goalId,goalTitle,completedDate,verifiedDate,score,managerAcknowledgedBy,evidenceCount,comments',
      );
      for (final g in goals) {
        final completed = g.completedDate?.toIso8601String() ?? '';
        final verified = g.verifiedDate?.toIso8601String() ?? '';
        final safeTitle = g.goalTitle.replaceAll(',', ' ');
        final safeComments = (g.comments ?? '').replaceAll(',', ' ');
        buffer.writeln([
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
        ].join(','));
      }

      final bytes = utf8.encode(buffer.toString());
      final fileName = 'repository_all_${DateTime.now().millisecondsSinceEpoch}.csv';
      final ref = _storage.ref().child('exports/all/$fileName');
      await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'text/csv'));
      final url = await ref.getDownloadURL();
      developer.log('CSV export (all) uploaded: $url');
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
      final goals = snap.docs.map((d) => RepositoryGoal.fromFirestore(d)).toList();

      final buffer = StringBuffer();
      buffer.writeln('Personal Development Hub – Repository Export (All Users)');
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

      final bytes = utf8.encode(buffer.toString());
      final fileName = 'repository_all_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ref = _storage.ref().child('exports/all/$fileName');
      await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'application/pdf'));
      final url = await ref.getDownloadURL();
      developer.log('PDF export (all) uploaded: $url');
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

      // Store as .pdf for convenience; real PDF generation can replace this later
      final bytes = utf8.encode(buffer.toString());
      final fileName =
          'repository_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ref = _storage.ref().child('exports/$userId/$fileName');
      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'application/pdf'),
      );
      final url = await ref.getDownloadURL();
      developer.log('PDF export (text report) uploaded: $url');
    } catch (e) {
      developer.log('Error exporting repository PDF: $e');
      rethrow;
    }
  }
}
