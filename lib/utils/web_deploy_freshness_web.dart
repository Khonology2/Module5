import 'dart:js_interop';
import 'dart:convert';
import 'package:web/web.dart' as web;

Future<String?> fetchLatestLiveVersion() async {
  final candidates = <String>[
    '/assets/data/daily-commits.json',
    '/assets/assets/data/daily-commits.json',
  ];

  for (final path in candidates) {
    final payload = await _fetchJson(path);
    if (payload == null) continue;
    final dynamic versionRaw = payload['version'];
    final version = versionRaw?.toString().trim();
    if (version != null && version.isNotEmpty) return version;
  }
  return null;
}

Future<Map<String, dynamic>?> _fetchJson(String path) async {
  try {
    final request = web.Request(
      '$path?ts=${DateTime.now().millisecondsSinceEpoch}'.toJS,
      web.RequestInit(cache: 'no-store'),
    );
    final response = await web.window.fetch(
      request,
    ).toDart;
    if (!response.ok) return null;
    final text = (await response.text().toDart).toDart;
    final decoded = json.decode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
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

