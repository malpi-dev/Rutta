import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

void main() {
  final world = buildDemoWorld(DateTime.utc(2026, 10, 7, 18));

  List<Order> of({String? customer, String? courier}) => [
    for (final o in world.orders)
      if ((customer == null || o.customerId == customer) &&
          (courier == null || o.courierId == courier))
        o,
  ];

  Map<OrderStatus, int> count(List<Order> orders) => {
    for (final s in OrderStatus.values)
      s: orders.where((o) => o.status == s).length,
  }..removeWhere((_, n) => n == 0);

  test('Alex has 5 orders', () {
    final alex = of(customer: DemoUsers.customerId);
    expect(alex, hasLength(5));
    expect(count(alex), {
      OrderStatus.inTransit: 1,
      OrderStatus.assigned: 1,
      OrderStatus.delivered: 2,
      OrderStatus.cancelled: 1,
    });
  });

  test('Carlos has 3 orders', () {
    final carlos = of(courier: DemoUsers.courierId);
    expect(carlos, hasLength(3));
    expect(count(carlos), {OrderStatus.assigned: 1, OrderStatus.delivered: 2});
  });

  test('no courier has two orders in progress', () {
    final byCourier = <String, int>{};
    for (final o in world.orders.where((o) => o.status.isInProgress)) {
      byCourier.update(o.courierId!, (n) => n + 1, ifAbsent: () => 1);
    }
    expect(byCourier.values.every((n) => n <= 1), isTrue);
  });

  test('events match the order status and are consistent', () {
    for (final order in world.orders) {
      final events = world.events.where((e) => e.orderId == order.id).toList();
      expect(events.last.status, order.status, reason: order.code);
      expect(order.updatedAt, events.last.createdAt);
      expect(order.createdAt, events.first.createdAt);
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i].createdAt.isAfter(events[i - 1].createdAt),
          isTrue,
          reason: order.code,
        );
        expect(
          events[i - 1].status.canTransitionTo(events[i].status),
          isTrue,
          reason:
              '${order.code} ${events[i - 1].status} -> ${events[i].status}',
        );
      }
    }
  });

  test('event ids are consecutive from 1 and routes are real', () {
    expect(world.events.map((e) => e.id), [
      for (var i = 1; i <= world.events.length; i++) i,
    ]);
    for (final o in world.orders) {
      expect(o.route.length, greaterThan(2));
      expect(o.routeDistanceMeters, inInclusiveRange(1500, 4000));
      expect(o.dropoff.name, isNull);
      expect(o.pickup.name, isNotNull);
    }
  });
}
