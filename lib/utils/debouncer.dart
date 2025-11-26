import 'dart:async';

/// Utility class for debouncing function calls
/// Useful for search inputs and other frequent events
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  /// Call the callback after the delay period
  /// If called again before the delay expires, the previous call is cancelled
  void call(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  /// Cancel any pending callback
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose the debouncer
  void dispose() {
    cancel();
  }
}

/// Debouncer specifically for string values (e.g., search queries)
class ValueDebouncer<T> {
  final Duration delay;
  final void Function(T value) callback;
  Timer? _timer;
  T? _pendingValue;

  ValueDebouncer({
    required this.callback,
    this.delay = const Duration(milliseconds: 500),
  });

  /// Set a new value to be debounced
  void setValue(T value) {
    _pendingValue = value;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (_pendingValue != null) {
        callback(_pendingValue as T);
        _pendingValue = null;
      }
    });
  }

  /// Immediately trigger the callback with the pending value
  void flush() {
    _timer?.cancel();
    if (_pendingValue != null) {
      callback(_pendingValue as T);
      _pendingValue = null;
    }
  }

  /// Cancel any pending callback
  void cancel() {
    _timer?.cancel();
    _pendingValue = null;
  }

  /// Dispose the debouncer
  void dispose() {
    cancel();
  }
}
