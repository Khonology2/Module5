// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? readBackendBaseUrlFromWebMeta() {
  final element =
      html.document.querySelector('meta[name="pdh-backend-base-url"]');
  final content = element?.getAttribute('content')?.trim() ?? '';
  if (content.isEmpty) return null;
  return content;
}
