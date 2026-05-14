import 'package:web/web.dart' as web;

import 'package:pdh/utils/uri_token_strip.dart';

/// Parses [window.location.href], strips `token` from query + hash query, then
/// [history.replaceState] so the bar matches what Flutter should show.
Uri? stripTokenFromBrowserLocationAndReturnCleanUri() {
  try {
    final href = web.window.location.href;
    if (href.isEmpty || !href.contains('token=')) return null;
    final u = Uri.parse(href);
    final clean = UriTokenStrip.stripTokenFromUri(u);
    if (clean.toString() == href) return null;
    web.window.history.replaceState(null, '', clean.toString());
    return clean;
  } catch (_) {
    return null;
  }
}
