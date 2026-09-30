import 'dart:async';

import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/demo/data/demo_store.dart';

/// Demo store without latency and with a 5 s simulation.
DemoStore testDemoStore({
  UserRole role = UserRole.customer,
  FixedClock? clock,
}) {
  return DemoStore.seeded(
    role: role,
    clock: clock ?? FixedClock(DateTime.utc(2026, 10, 7, 18)),
    latency: Duration.zero,
    simulationDuration: const Duration(seconds: 5),
  );
}

/// Subscribes to a stream and collects its data and errors.
class Collected<T> {
  Collected(Stream<T> stream) {
    _sub = stream.listen(
      values.add,
      onError: errors.add,
      onDone: () => done = true,
    );
  }

  final List<T> values = <T>[];
  final List<Object> errors = <Object>[];
  bool done = false;
  late final StreamSubscription<T> _sub;

  void cancel() => unawaited(_sub.cancel());
}

/// Captures the result of a future inside `fakeAsync`, where it cannot be
/// awaited.
class Outcome<T> {
  Outcome(Future<T> future) {
    unawaited(future.then((v) => value = v, onError: (Object e) => error = e));
  }

  T? value;
  Object? error;
}
