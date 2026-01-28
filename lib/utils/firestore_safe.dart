import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_core/firebase_core.dart';
import 'package:pdh/utils/firestore_web_circuit_breaker.dart';

/// Centralized Firestore resilience for Web-first apps.
///
/// Goals:
/// - Detect Firestore Web "INTERNAL ASSERTION FAILED: Unexpected state" and
///   trigger the one-time reload circuit breaker.
/// - Retry normal transient failures (network/offline/unavailable) with
///   short exponential backoff + jitter.
/// - Provide a stream helper that hooks errors to the circuit breaker and
///   avoids propagating noisy errors into widgets.
class FirestoreSafe {
  FirestoreSafe._();

  static final Random _rng = Random();

  static bool _isInternalUnexpectedState(dynamic error) {
    try {
      final obj = error is Object ? error : Exception(error.toString());
      return FirestoreWebCircuitBreaker.isFirestoreInternalUnexpectedState(obj);
    } catch (_) {
      return error.toString().contains('INTERNAL ASSERTION FAILED') &&
          error.toString().contains('Unexpected state');
    }
  }

  static bool _isTransient(dynamic error) {
    if (_isInternalUnexpectedState(error)) return false;

    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      // Common transient codes across Firebase/Firestore.
      if (code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'aborted' ||
          code == 'cancelled' ||
          code == 'resource-exhausted') {
        return true;
      }
    }

    // Fallback to message heuristics.
    final msg = error.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('offline') ||
        msg.contains('connection') ||
        msg.contains('unavailable') ||
        msg.contains('failed-precondition');
  }

  static void _hookError(dynamic error) {
    if (_isInternalUnexpectedState(error)) {
      final obj = error is Object ? error : Exception(error.toString());
      FirestoreWebCircuitBreaker.maybeReload(obj);
    }
  }

  /// Retry wrapper for Firestore operations.
  ///
  /// - For Firestore Web internal assertion failures: triggers circuit breaker,
  ///   then rethrows (reload is the recovery).
  /// - For transient failures: retries [retries] times with backoff.
  static Future<T> retry<T>(
    Future<T> Function() op, {
    int retries = 2,
    Duration baseDelay = const Duration(milliseconds: 200),
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await op();
      } catch (e) {
        _hookError(e);

        // If this is the internal Firestore state error, reload is the fix.
        if (_isInternalUnexpectedState(e)) rethrow;

        final canRetry = _isTransient(e) && attempt < retries;
        if (!canRetry) rethrow;

        final backoffMs =
            (baseDelay.inMilliseconds * pow(2, attempt)).toInt();
        final jitterMs = _rng.nextInt(120);
        await Future.delayed(Duration(milliseconds: backoffMs + jitterMs));
        attempt++;
      }
    }
  }

  /// Add an error hook to a Firestore snapshot stream.
  ///
  /// We intentionally do NOT forward the error to downstream listeners, because
  /// UI widgets often display noisy stack traces. For the internal assertion
  /// failure, a reload will occur; for other errors, consumers can rely on the
  /// last good value / local cache patterns.
  static Stream<T> stream<T>(Stream<T> source) {
    return source.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stack, sink) {
          _hookError(error);
          // Swallow the error to avoid UI stack traces.
        },
      ),
    );
  }

  static Future<DocumentSnapshot<T>> getDoc<T>(
    DocumentReference<T> ref, {
    int retries = 2,
  }) {
    return retry(() => ref.get(), retries: retries);
  }

  static Future<QuerySnapshot<T>> getQuery<T>(
    Query<T> query, {
    int retries = 2,
  }) {
    return retry(() => query.get(), retries: retries);
  }

  static Future<void> setDoc<T>(
    DocumentReference<T> ref,
    T data, {
    SetOptions? options,
    int retries = 2,
  }) {
    return retry(
      () => options == null ? ref.set(data) : ref.set(data, options),
      retries: retries,
    );
  }

  static Future<void> updateDoc<T>(
    DocumentReference<T> ref,
    Map<String, dynamic> data, {
    int retries = 2,
  }) {
    return retry(() => ref.update(data), retries: retries);
  }

  static Future<void> deleteDoc<T>(
    DocumentReference<T> ref, {
    int retries = 2,
  }) {
    return retry(() => ref.delete(), retries: retries);
  }

  static Future<DocumentReference<T>> addDoc<T>(
    CollectionReference<T> col,
    T data, {
    int retries = 2,
  }) {
    return retry(() => col.add(data), retries: retries);
  }

  static Future<R> runTransaction<R>(
    FirebaseFirestore firestore,
    TransactionHandler<R> handler, {
    int retries = 1,
  }) {
    return retry(() => firestore.runTransaction(handler), retries: retries);
  }

  static Future<void> writeBatch(
    WriteBatch batch, {
    int retries = 1,
  }) {
    return retry(() => batch.commit(), retries: retries);
  }
}

