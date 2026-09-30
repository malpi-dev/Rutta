import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/data/mock_device_location_repository.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

import '../../../helpers/demo.dart';

void main() {
  test('permissions are always granted', () async {
    final repo = MockDeviceLocationRepository(testDemoStore());
    expect(await repo.checkAccess(), LocationAccess.granted);
    expect(await repo.requestAccess(), LocationAccess.granted);
    await repo.openAppSettings();
    await repo.openLocationSettings();
  });

  test(
    'emits nothing without an order in progress, then follows the order',
    () {
      fakeAsync((async) {
        final store = testDemoStore(role: UserRole.courier);
        final c = Collected(
          MockDeviceLocationRepository(store).watchPosition(),
        );
        async.elapse(const Duration(seconds: 10));
        expect(c.values, isEmpty);

        final order = store.order('demo-order-1043')!;
        store.advance(
          order.id,
          OrderStatus.pickedUp,
          actorId: DemoUsers.courierId,
        );
        async.elapse(const Duration(seconds: 1));
        expect(c.values.first.point, order.pickup.point);

        c.values.clear();
        store.advance(
          order.id,
          OrderStatus.inTransit,
          actorId: DemoUsers.courierId,
        );
        async.elapse(const Duration(seconds: 3));
        expect(c.values.length, greaterThan(2));
        var previous = -1.0;
        for (final p in c.values) {
          final traveled = projectOntoRoute(
            order.route,
            p.point,
          ).traveledMeters;
          expect(traveled, greaterThanOrEqualTo(previous));
          previous = traveled;
        }

        // After the trip it keeps repeating the destination every 5 s.
        async.elapse(const Duration(seconds: 12));
        expect(c.values.last.point, order.route.last);

        store.advance(
          order.id,
          OrderStatus.delivered,
          actorId: DemoUsers.courierId,
        );
        c.cancel();
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
      });
    },
  );
}
