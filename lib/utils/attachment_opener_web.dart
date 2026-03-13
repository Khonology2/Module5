// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<bool> openAttachmentUrl(String url) async {
  html.window.open(url, '_blank');
  return true;
}

