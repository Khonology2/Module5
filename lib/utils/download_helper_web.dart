// Web implementation using dart:html
import 'dart:convert';
import 'dart:html' as html;

void downloadJsonFile(String filename, String jsonContent) {
  final bytes = utf8.encode(jsonContent);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}


