import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/features/orders/data/demo_routes.dart';
import 'package:rutta/features/tracking/data/demo_courier_simulator.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

void main() {
  final route = demoRoutes['r1']!.points;
  final clock = FixedClock(DateTime.utc(2026, 10, 7, 18));

  DemoCourierSimulator simulator({double startFraction = 0}) =>
      DemoCourierSimulator(
        route: route,
        clock: clock,
        targetDuration: const Duration(seconds: 5),
        startFraction: startFraction,
      );

  test('emits from the start to route.last, stays on the route and closes', () {
    fakeAsync((async) {
      final positions = <DevicePosition>[];
      var done = false;
      simulator().positions().listen(positions.add, onDone: () => done = true);
      async.elapse(const Duration(seconds: 10));

      expect(done, isTrue);
      expect(positions.first.point, route.first);
      expect(positions.last.point, route.last);
      expect(positions.length, greaterThan(3));
      var previous = -1.0;
      for (final p in positions) {
        final projection = projectOntoRoute(route, p.point);
        expect(projection.distanceToRouteMeters, lessThan(1));
        expect(projection.traveledMeters, greaterThanOrEqualTo(previous));
        previous = projection.traveledMeters;
        expect(p.speedMps, 8.3);
        expect(p.accuracyMeters, 5);
        expect(p.heading, inInclusiveRange(0, 360));
        expect(p.timestamp, clock.now);
      }
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('startFraction starts part of the way along the route', () {
    fakeAsync((async) {
      final positions = <DevicePosition>[];
      final sub = simulator(startFraction: 0.15).positions().listen(
        positions.add,
      );
      async.flushMicrotasks();
      final total = routeLengthMeters(route);
      final traveled = projectOntoRoute(
        route,
        positions.first.point,
      ).traveledMeters;
      expect(traveled, closeTo(total * 0.15, 1));
      unawaited(sub.cancel());
    });
  });

  test('cancelling the subscription stops the timer', () {
    fakeAsync((async) {
      final positions = <DevicePosition>[];
      final sub = simulator().positions().listen(positions.add);
      async.elapse(const Duration(seconds: 2));
      final count = positions.length;
      expect(async.pendingTimers, isNotEmpty);
      unawaited(sub.cancel());
      expect(async.pendingTimers, isEmpty);
      async.elapse(const Duration(seconds: 10));
      expect(positions.length, count);
    });
  });
}
