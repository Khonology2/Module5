



import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('PDF generation with sample data', () async {
    // Test data similar to what would be exported from the app
    final testData = {
      'user_info': {'name': 'Test User', 'email': 'test@example.com'},
      'settings': {'notifications': true, 'dark_mode': false},
      'preferences': {'language': 'en', 'timezone': 'UTC'},
    };

    // Create a PDF document similar to what the app would generate
    final pdf = pw.Document();

    // Add title page
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Personal Development Hub',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Data Export', style: pw.TextStyle(fontSize: 20)),
              pw.SizedBox(height: 40),
              pw.Text(
                'Generated on: Test Date',
                style: pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    // Add content pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return testData.entries.map<pw.Widget>((entry) {
            final section = entry.key;
            final sectionData = entry.value;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 1,
                  child: pw.Text(
                    section.replaceAll('_', ' ').toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                _buildTestPdfSection(section, sectionData),
              ],
            );
          }).toList();
        },
      ),
    );

    // Save the PDF to bytes
    final bytes = await pdf.save();

    // Verify PDF was generated successfully
    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(0));
    expect(bytes.length, greaterThan(1024)); // Should be at least 1KB
  });

  test('PDF file saving simulation', () async {
    // Simulate the PDF saving process
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) =>
            pw.Center(child: pw.Text('Test PDF Content')),
      ),
    );

    // Save the PDF to a temporary file
    final bytes = await pdf.save();
    final tempDir = await Directory.systemTemp.createTemp();
    final filePath = '${tempDir.path}/test_export.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // Verify file was created and has content
    expect(await file.exists(), true);
    expect(bytes.length, greaterThan(0));
    final fileSize = await file.length();
    expect(fileSize, equals(bytes.length));

    // Verify file extension
    expect(filePath.endsWith('.pdf'), true);

    // Clean up
    await file.delete();
    await tempDir.delete(recursive: true);
  });

  test('PDF content structure test', () async {
    // Test that the PDF contains expected sections
    final testData = {
      'user_profile': {'name': 'John Doe', 'role': 'Employee'},
      'app_settings': {'theme': 'dark', 'notifications': true},
    };

    final pdf = pw.Document();

    // Add pages for each section
    testData.forEach((sectionName, sectionData) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            children: [
              pw.Text(
                sectionName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Section data: $sectionData'),
            ],
          ),
        ),
      );
    });

    final bytes = await pdf.save();

    // Verify PDF has content for each section
    expect(bytes.length, greaterThan(0));
    expect(pdf.document.pdfPageList.pages.length, equals(testData.length));
  });
}

// Helper function to build PDF sections for testing
pw.Widget _buildTestPdfSection(String section, dynamic data) {
  if (data is Map) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: data.entries.map<pw.Widget>((entry) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('${entry.key}: ${entry.value}'),
        );
      }).toList(),
    );
  } else if (data is List) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: data.asMap().entries.map<pw.Widget>((entry) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('${entry.key + 1}. ${entry.value}'),
        );
      }).toList(),
    );
  } else {
    return pw.Text(data.toString());
  }
}
