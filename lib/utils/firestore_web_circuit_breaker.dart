import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdh/utils/web_storage_stub.dart'
    if (dart.library.html) 'package:pdh/utils/web_storage_web.dart';
import 'package:pdh/utils/web_reload_stub.dart'
    if (dart.library.html) 'package:pdh/utils/web_reload_web.dart';

/// Firestore Web SDK sometimes enters an unrecoverable internal state
/// ("INTERNAL ASSERTION FAILED: Unexpected state") and will spam the console.
///
/// The only reliable recovery is a full page reload. We do that once per
/// session when this specific signature is detected.
class FirestoreWebCircuitBreaker {
  static bool _triggered = false;
  static bool isBroken = false;
  // Default to true on web; guarded to reload once per session.
  // Disabled for development to allow retry logic to work
  static bool enableAutoReload = false;
  static const String _reloadFlagKey = 'pdh_fs_reload_attempted';

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
    // Only allow one reload attempt per browser storage session.
    if (enableAutoReload && readWebStorage(_reloadFlagKey) == null) {
      try {
        writeWebStorage(
          _reloadFlagKey,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
        // Force a full reload; this is the only known reliable recovery for
        // Firestore Web "Unexpected state" internal assertion failures.
        reloadPage();
      } catch (_) {
        // If storage is blocked, skip reload and mark broken.
      }
    }
    // Mark Firestore as broken to avoid loops.
    //
    // IMPORTANT: Do NOT disable the Firestore network here.
    // Disabling the network makes the app permanently "offline" for the session
    // and breaks settings toggles/writes even when Firestore would otherwise
    // recover. We only want to surface the state (and optionally reload), not
    // hard-disable functionality.
    isBroken = true;
  }

  /// Manual recovery button for when auto-reload is blocked.
  static void forceReload() {
    if (!kIsWeb) return;
    try {
      reloadPage();
    } catch (_) {}
  }
}
