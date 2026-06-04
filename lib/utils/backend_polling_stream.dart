import 'dart:async';

import 'dart:developer' as developer;

/// Polls a backend fetch function on a fixed interval and emits updates.
Stream<T> backendPollingStream<T>({
  required Future<T> Function() fetch,
  Duration interval = const Duration(seconds: 5),
  T? initialValue,
  void Function(Object error, StackTrace? stackTrace)? onError,
}) async* {
  T? lastValue = initialValue;
  while (true) {
    try {
      lastValue = await fetch();
      yield lastValue as T;
    } catch (error, stackTrace) {
      developer.log('backendPollingStream error: $error', stackTrace: stackTrace);
      onError?.call(error, stackTrace);
      if (lastValue != null) {
        yield lastValue as T;
      }
    }
    await Future.delayed(interval);
  }
}

/// Polls a list fetch and maps each item through [mapper].
Stream<List<T>> backendPollingListStream<T>({
  required Future<List<Map<String, dynamic>>> Function() fetch,
  required T Function(Map<String, dynamic> item) mapper,
  Duration interval = const Duration(seconds: 5),
}) {
  return backendPollingStream<List<T>>(
    interval: interval,
    initialValue: const [],
    fetch: () async {
      final items = await fetch();
      return items.map(mapper).toList();
    },
  );
}

/// Cancellable polling stream backed by a [StreamController].
Stream<T> createManagedPollingStream<T>({
  required Future<T> Function() fetch,
  Duration interval = const Duration(seconds: 5),
  T? initialValue,
}) {
  late StreamController<T> controller;
  Timer? timer;
  var disposed = false;

  Future<void> poll() async {
    if (disposed || controller.isClosed) return;
    try {
      final value = await fetch();
      if (!disposed && !controller.isClosed) {
        controller.add(value);
      }
    } catch (error, stackTrace) {
      developer.log('createManagedPollingStream error: $error', stackTrace: stackTrace);
      if (initialValue != null && !disposed && !controller.isClosed) {
        controller.add(initialValue);
      }
    }
  }

  controller = StreamController<T>(
    onListen: () {
      poll();
      timer = Timer.periodic(interval, (_) => poll());
    },
    onCancel: () {
      disposed = true;
      timer?.cancel();
    },
  );

  return controller.stream;
}
