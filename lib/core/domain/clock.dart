/// Injectable time source. Use it instead of `DateTime.now()`.
// ignore: one_member_abstracts, port interface.
abstract interface class Clock {
  DateTime nowUtc();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Deterministic clock for tests. [now] is mutable so tests can advance time.
class FixedClock implements Clock {
  FixedClock(DateTime now) : now = now.toUtc();

  DateTime now;

  void advance(Duration by) => now = now.add(by);

  @override
  DateTime nowUtc() => now;
}
