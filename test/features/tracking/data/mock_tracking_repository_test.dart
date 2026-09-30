import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/demo/data/demo_store.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/data/mock_tracking_repository.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';

import '../../../helpers/demo.dart';

void main() {
  CourierLocation location(String orderId, String courierId, DemoStore store) =>
      CourierLocation(
        courierId: courierId,
        orderId: orderId,
        point: store.order(orderId)!.pickup.point,
        recordedAt: DateTime.utc(2026, 10, 7, 18),
      );

  test(
    'customer sees RT-1042 advance, get delivered and lose its location',
    () {
      fakeAsync((async) {
        final store = testDemoStore();
        final repo = MockTrackingRepository(store);
        final c = Collected(repo.watchCourierLocation('demo-order-1042'));
        async.elapse(const Duration(seconds: 10));

        final points = c.values.whereType<CourierLocation>().toList();
        expect(points.length, greaterThan(2));
        final route = store.order('demo-order-1042')!.route;
        var previous = -1.0;
        for (final p in points) {
          final traveled = projectOntoRoute(route, p.point).traveledMeters;
          expect(traveled, greaterThanOrEqualTo(previous));
          previous = traveled;
        }
        expect(store.order('demo-order-1042')!.status, OrderStatus.delivered);
        expect(
          store.events('demo-order-1042').last.status,
          OrderStatus.delivered,
        );
        expect(c.values.last, isNull);
        expect(async.pendingTimers, isEmpty);
        c.cancel();
      });
    },
  );

  test('a customer cannot publish a location', () {
    fakeAsync((async) {
      final store = testDemoStore();
      final outcome = Outcome(
        MockTrackingRepository(store).publishLocation(
          location('demo-order-1042', DemoUsers.otherCourierId, store),
        ),
      );
      async.flushMicrotasks();
      expect(outcome.error, isA<NoActiveOrderError>());
    });
  });

  test('a courier without an order in progress cannot publish', () {
    fakeAsync((async) {
      final store = testDemoStore(role: UserRole.courier);
      final outcome = Outcome(
        MockTrackingRepository(store).publishLocation(
          location('demo-order-1043', DemoUsers.courierId, store),
        ),
      );
      async.flushMicrotasks();
      expect(outcome.error, isA<NoActiveOrderError>());
    });
  });

  test('a courier with an order in progress can publish', () {
    fakeAsync((async) {
      final store = testDemoStore(role: UserRole.courier)
        ..advance(
          'demo-order-1043',
          OrderStatus.pickedUp,
          actorId: DemoUsers.courierId,
        );
      final outcome = Outcome(
        MockTrackingRepository(store).publishLocation(
          location('demo-order-1043', DemoUsers.courierId, store),
        ),
      );
      async.flushMicrotasks();
      expect(outcome.error, isNull);
      expect(store.location('demo-order-1043'), isNotNull);
    });
  });
}
