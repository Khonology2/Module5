// Web implementation using package:web
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadJsonFile(String filename, String jsonContent) {
  final bytes = utf8.encode(jsonContent);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
