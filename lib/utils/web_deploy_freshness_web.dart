import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String?> fetchCurrentDeployCommit() async {
  try {
    final request = web.Request(
      '/.ci-source-commit?ts=${DateTime.now().millisecondsSinceEpoch}'.toJS,
      web.RequestInit(cache: 'no-store'),
    );
    final response = await web.window.fetch(
      request,
    ).toDart;
    if (!response.ok) return null;
    final text = (await response.text().toDart).toDart.trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

void forceHardReload() {
  final origin = web.window.location.origin;
  final path = web.window.location.pathname;
  final search = web.window.location.search;
  final hash = web.window.location.hash;
  final bust = 'app_refresh=${DateTime.now().millisecondsSinceEpoch}';
  final separator = search.contains('?') ? '&' : '?';
  final nextUrl = '$origin$path$search$separator$bust$hash';
  web.window.location.replace(nextUrl);
}

