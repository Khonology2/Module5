// Web implementation: return current origin for HTTP referrer whitelist.
import 'package:web/web.dart' as web;

String? getWebOrigin() {
  try {
    return web.window.location.origin;
  } catch (_) {
    return null;
  }
}
