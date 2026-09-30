import 'dart:async';

import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_store.dart';

/// Single-subscription stream of `read()`: waits [DemoStore.latency], emits,
/// then re-emits after every store change. A [DomainError] thrown by [read]
/// becomes a stream error. Timer and subscription die with the listener.
Stream<T> watchStore<T>(
  DemoStore store,
  T Function() read, {
  void Function()? onStart,
}) {
  Timer? timer;
  StreamSubscription<void>? sub;
  late final StreamController<T> controller;

  void emit() {
    try {
      controller.add(read());
    } on DomainError catch (e) {
      controller.addError(e);
    }
  }

  controller = StreamController<T>(
    onListen: () {
      onStart?.call();
      timer = Timer(store.latency, () {
        emit();
        sub = store.changes.listen((_) => emit());
      });
    },
    onCancel: () async {
      timer?.cancel();
      await sub?.cancel();
    },
  );
  return controller.stream;
}
