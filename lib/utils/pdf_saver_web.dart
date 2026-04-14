// This file targets web platform; allow web-only APIs and deprecated dart:html usage
// since the implementation intentionally uses browser APIs.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:developer' as developer;

Future<String?> savePdfBytes(String fileName, List<int> bytes) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  developer.log('PDF download triggered for $fileName');
  return null; // No filesystem path on web
}
