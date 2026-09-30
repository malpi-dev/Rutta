import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/orders/data/mock_orders_repository.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/demo.dart';

void main() {
  const step = Duration(milliseconds: 10);

  test('customer sees their 5 orders, newest first', () {
    fakeAsync((async) {
      final repo = MockOrdersRepository(testDemoStore());
      final c = Collected(repo.watchMyOrders());
      async.elapse(step);
      expect(c.values.single.map((o) => o.code), [
        'RT-1043',
        'RT-1042',
        'RT-1038',
        'RT-1035',
        'RT-1031',
      ]);
      c.cancel();
    });
  });

  test('courier sees their 3 orders', () {
    fakeAsync((async) {
      final repo = MockOrdersRepository(
        testDemoStore(role: UserRole.courier),
      );
      final c = Collected(repo.watchMyOrders());
      async.elapse(step);
      expect(c.values.single.map((o) => o.code), [
        'RT-1043',
        'RT-1035',
        'RT-1029',
      ]);
      c.cancel();
    });
  });

  test(
    'happy path emits changes and adds events; delivery clears location',
    () {
      fakeAsync((async) {
        final store = testDemoStore(role: UserRole.courier);
        final repo = MockOrdersRepository(store);
        final list = Collected(repo.watchMyOrders());
        final one = Collected(repo.watchOrder('demo-order-1043'));
        final events = Collected(repo.watchStatusEvents('demo-order-1043'));
        async.elapse(step);
        expect(events.values.last.map((e) => e.status), [
          OrderStatus.created,
          OrderStatus.assigned,
        ]);

        for (final next in [
          OrderStatus.pickedUp,
          OrderStatus.inTransit,
          OrderStatus.delivered,
        ]) {
          if (next == OrderStatus.delivered) {
            store.setLocation(
              'demo-order-1043',
              CourierLocation(
                courierId: DemoUsers.courierId,
                orderId: 'demo-order-1043',
                point: store.order('demo-order-1043')!.pickup.point,
                recordedAt: DateTime.utc(2026, 10, 7, 18),
              ),
            );
            expect(store.location('demo-order-1043'), isNotNull);
          }
          final outcome = Outcome(repo.advanceStatus('demo-order-1043', next));
          async.elapse(step);
          expect(outcome.error, isNull);
          expect(outcome.value!.status, next);
          expect(one.values.last.status, next);
          expect(
            list.values.last
                .firstWhere((o) => o.id == 'demo-order-1043')
                .status,
            next,
          );
        }
        expect(
          events.values.last.map((e) => e.status).last,
          OrderStatus.delivered,
        );
        expect(events.values.last, hasLength(5));
        expect(store.location('demo-order-1043'), isNull);
        for (final c in [list, one, events]) {
          c.cancel();
        }
      });
    },
  );

  test('skipping a step throws InvalidTransitionError', () {
    fakeAsync((async) {
      final repo = MockOrdersRepository(testDemoStore(role: UserRole.courier));
      final outcome = Outcome(
        repo.advanceStatus('demo-order-1043', OrderStatus.delivered),
      );
      async.elapse(step);
      expect(
        outcome.error,
        isA<InvalidTransitionError>()
            .having((e) => e.from, 'from', 'assigned')
            .having((e) => e.to, 'to', 'delivered'),
      );
    });
  });

  test(
    'advancing an order of another courier throws NotAssignedToYouError',
    () {
      fakeAsync((async) {
        final repo = MockOrdersRepository(
          testDemoStore(role: UserRole.courier),
        );
        final outcome = Outcome(
          repo.advanceStatus('demo-order-1042', OrderStatus.delivered),
        );
        async.elapse(step);
        expect(outcome.error, isA<NotAssignedToYouError>());
      });
    },
  );

  test('a second order in progress throws CourierBusyError', () {
    fakeAsync((async) {
      final store = testDemoStore(role: UserRole.courier)
        ..addOrder(
          buildOrder(
            id: 'extra',
            code: 'RT-9999',
            courierId: DemoUsers.courierId,
            customerId: DemoUsers.customerId,
          ),
        );
      final repo = MockOrdersRepository(store);
      final first = Outcome(
        repo.advanceStatus('demo-order-1043', OrderStatus.pickedUp),
      );
      async.elapse(step);
      expect(first.error, isNull);
      final second = Outcome(repo.advanceStatus('extra', OrderStatus.pickedUp));
      async.elapse(step);
      expect(second.error, isA<CourierBusyError>());
    });
  });

  test('watchOrder of an unknown id errors with NotFoundError', () {
    fakeAsync((async) {
      final repo = MockOrdersRepository(testDemoStore());
      final c = Collected<Order>(repo.watchOrder('nope'));
      async.elapse(step);
      expect(c.errors.single, isA<NotFoundError>());
      c.cancel();
    });
  });
}
