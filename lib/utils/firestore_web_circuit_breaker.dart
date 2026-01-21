import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdh/utils/web_reload_stub.dart'
    if (dart.library.html) 'package:pdh/utils/web_reload_web.dart';

/// Firestore Web SDK sometimes enters an unrecoverable internal state
/// ("INTERNAL ASSERTION FAILED: Unexpected state") and will spam the console.
///
/// The only reliable recovery is a full page reload. We do that once per
/// session when this specific signature is detected.
class FirestoreWebCircuitBreaker {
  static bool _triggered = false;

  static bool isFirestoreInternalUnexpectedState(Object error) {
    final s = error.toString();
    return s.contains('FIRESTORE') &&
        s.contains('INTERNAL ASSERTION FAILED') &&
        s.contains('Unexpected state');
  }

  static void maybeReload(Object error) {
    if (!kIsWeb || _triggered) return;
    if (!isFirestoreInternalUnexpectedState(error)) return;
    _triggered = true;
    reloadPage();
  }
}

