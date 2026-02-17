import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class EmployeeExportService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> exportEmployeeData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        developer.log('Export attempt ${retryCount + 1} of $maxRetries');

        // Get user profile with retry logic
        final userDoc = await _getUserProfileWithRetry(user.uid);

        // Get goals with small limit to avoid errors
        final goalsQuery = await _getGoalsWithRetry(user.uid);

        // Get other user data
        final activitiesQuery = await _getActivitiesWithRetry(user.uid);

        final exportData = {
          'profile': _filterProfileData(userDoc.data() as Map<String, dynamic>),
          'goals': goalsQuery.docs.map((doc) => doc.data()).toList(),
          'activities': activitiesQuery.docs.map((doc) => doc.data()).toList(),
          'exportDate': DateTime.now().toIso8601String(),
        };

        // Generate PDF
        final pdf = await _generatePdf(exportData);

        // Save and open file
        final fileName =
            'employee-export-${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = await _savePdfFile(fileName, pdf);

        // Try to open the file
        final result = await OpenFile.open(file.path);

        if (result.type != ResultType.done) {
          developer.log('PDF saved to: ${file.path}');
        } else {
          developer.log('Data exported successfully!');
        }

        return; // Success, exit retry loop
      } catch (e, stackTrace) {
        developer.log(
          'Export attempt ${retryCount + 1} failed: $e',
          error: e,
          stackTrace: stackTrace,
        );

        retryCount++;

        if (retryCount >= maxRetries) {
          // Final attempt failed, show user-friendly error
          String errorMessage = _getErrorMessage(e);
          developer.log(
            'Export failed after $maxRetries attempts: $errorMessage',
          );
          throw Exception('$errorMessage\n\nTechnical details: $e');
        } else {
          // Wait before retry
          await Future.delayed(const Duration(seconds: 2));
          developer.log('Retrying export in 2 seconds...');
        }
      }
    }
  }

  static Future<DocumentSnapshot> _getUserProfileWithRetry(
    String userId,
  ) async {
    try {
      return await _firestore.collection('users').doc(userId).get();
    } catch (e) {
      developer.log('Error getting user profile: $e');
      rethrow;
    }
  }

  static Future<QuerySnapshot> _getGoalsWithRetry(String userId) async {
    try {
      return await _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .limit(1) // Very small limit to avoid errors
          .get();
    } catch (e) {
      developer.log('Error getting goals: $e');
      rethrow;
    }
  }

  static Future<QuerySnapshot> _getActivitiesWithRetry(String userId) async {
    try {
      return await _firestore
          .collection('activities')
          .where('userId', isEqualTo: userId)
          .limit(2) // Small limit
          .get();
    } catch (e) {
      developer.log('Error getting activities: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _filterProfileData(
    Map<String, dynamic> profileData,
  ) {
    return {
      'displayName': profileData['displayName'],
      'email': profileData['email'],
      'department': profileData['department'],
      'jobTitle': profileData['jobTitle'],
      'photoURL': profileData['photoURL'],
      'createdAt': profileData['createdAt'],
      'lastUpdated': profileData['lastUpdated'],
    };
  }

  static Future<pw.Document> _generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          // Title
          widgets.add(
            pw.Text(
              'Employee Data Export',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          );
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(
            pw.Text(
              'Generated: ${DateTime.now().toString()}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
          widgets.add(pw.SizedBox(height: 20));

          // Profile section
          if (data['profile'] != null) {
            widgets.add(_buildSection('Profile', data['profile']));
          }

          // Goals section
          if (data['goals'] != null && (data['goals'] as List).isNotEmpty) {
            widgets.add(_buildSection('Goals', data['goals']));
          }

          // Activities section
          if (data['activities'] != null &&
              (data['activities'] as List).isNotEmpty) {
            widgets.add(_buildSection('Activities', data['activities']));
          }

          return widgets;
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSection(String title, dynamic data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          child: pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 10),
        _buildDataContent(data),
      ],
    );
  }

  static pw.Widget _buildDataContent(dynamic data) {
    if (data == null) {
      return pw.Text('No data available');
    }

    try {
      if (data is Map) {
        final items = <pw.Widget>[];
        data.forEach((key, value) {
          try {
            String displayValue = 'N/A';
            if (value != null) {
              displayValue = value.toString();
              if (displayValue.length > 50) {
                displayValue = '${displayValue.substring(0, 50)}...';
              }
            }
            items.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '${key.toString().replaceAll('_', ' ').toUpperCase()}: $displayValue',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            );
          } catch (e) {
            items.add(
              pw.Text(
                '${key.toString()}: Error displaying value',
                style: const pw.TextStyle(fontSize: 9),
              ),
            );
          }
        });
        return pw.Column(children: items);
      } else if (data is List && data.length <= 3) {
        final items = <pw.Widget>[];
        for (int i = 0; i < data.length; i++) {
          try {
            final item = data[i];
            String itemText = item.toString();
            if (itemText.length > 50) {
              itemText = '${itemText.substring(0, 50)}...';
            }
            items.add(
              pw.Text(
                '${i + 1}. $itemText',
                style: const pw.TextStyle(fontSize: 9),
              ),
            );
          } catch (e) {
            items.add(
              pw.Text(
                '${i + 1}. Error displaying item',
                style: const pw.TextStyle(fontSize: 9),
              ),
            );
          }
        }
        return pw.Column(children: items);
      } else {
        return pw.Text('Data type not supported or too large');
      }
    } catch (e) {
      return pw.Text('Error processing data: ${e.toString().substring(0, 50)}');
    }
  }

  static Future<File> _savePdfFile(String fileName, pw.Document pdf) async {
    // Sanitize filename for Windows
    final safeFileName = fileName.replaceAll(RegExp(r'[<>:"|?*]'), '_');

    try {
      final directory = await getApplicationDocumentsDirectory();
      final safePath = '${directory.path}/$safeFileName'.replaceAll('\\', '/');
      final file = File(safePath);
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      developer.log('Failed to save to documents directory: $e');
      // Fallback to temporary directory
      try {
        final tempDir = await getTemporaryDirectory();
        final safePath = '${tempDir.path}/$safeFileName'.replaceAll('\\', '/');
        final file = File(safePath);
        await file.writeAsBytes(await pdf.save());
        return file;
      } catch (e) {
        developer.log('Failed to save to temp directory: $e');
        // Last resort - try Downloads folder on Windows
        try {
          final downloadsPath = Platform.isWindows
              ? '${Platform.environment['USERPROFILE']}/Downloads/$safeFileName'
              : safeFileName;
          final file = File(downloadsPath.replaceAll('\\', '/'));
          await file.writeAsBytes(await pdf.save());
          return file;
        } catch (e) {
          developer.log('Failed all save attempts: $e');
          throw Exception(
            'Unable to save PDF file. Please check file permissions.',
          );
        }
      }
    }
  }

  static String _getErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('INTERNAL ASSERTION FAILED')) {
      return 'Database temporarily unavailable. Please try again.';
    } else if (errorString.contains('_Namespace') ||
        errorString.contains('unsupported operation')) {
      return 'File system error. Please try again or check file permissions.';
    } else if (errorString.contains('TooManyPagesException')) {
      return 'Data too large for PDF. Please contact support.';
    } else if (errorString.contains('OutOfMemoryError')) {
      return 'Insufficient memory. Please try with smaller data.';
    } else if (errorString.contains('permission-denied') ||
        errorString.contains('access denied')) {
      return 'File access denied. Please check permissions.';
    } else if (errorString.contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your connection.';
    } else {
      return 'Export failed. Please try again with smaller data or contact support.';
    }
  }
}

void main() async {
  try {
    developer.log('Starting employee data export...');
    await EmployeeExportService.exportEmployeeData();
    developer.log('Export completed successfully!');
  } catch (e) {
    developer.log('Export failed: $e');
    exit(1);
  }
}
