import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/utils/web_storage_stub.dart'
    if (dart.library.html) 'package:pdh/utils/web_storage_web.dart';

/// Firestore Web SDK sometimes enters an unrecoverable internal state
/// ("INTERNAL ASSERTION FAILED: Unexpected state") and will spam the console.
///
/// The only reliable recovery is a full page reload. We do that once per
/// session when this specific signature is detected.
class FirestoreWebCircuitBreaker {
  static bool _triggered = false;
  static bool isBroken = false;
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
      } catch (_) {
        // If storage is blocked, skip reload and mark broken.
      }
    }
    // Mark Firestore as broken to avoid loops and disable the network.
    isBroken = true;
    try {
      FirebaseFirestore.instance.disableNetwork();
    } catch (_) {
      // ignore
    }
  }
}

