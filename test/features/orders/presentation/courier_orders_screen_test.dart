import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';
import 'package:rutta/features/orders/presentation/courier_orders_screen.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/demo.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/pump_app.dart';

class _StubOrders implements OrdersRepository {
  _StubOrders(this._watchMyOrders);

  final Stream<List<Order>> Function() _watchMyOrders;

  @override
  Stream<List<Order>> watchMyOrders() => _watchMyOrders();

  @override
  Stream<Order> watchOrder(String orderId) => throw UnimplementedError();

  @override
  Stream<List<OrderStatusEvent>> watchStatusEvents(String orderId) =>
      throw UnimplementedError();

  @override
  Future<Order> advanceStatus(String orderId, OrderStatus next) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('loading shows a skeleton', (tester) async {
    final store = testDemoStore(role: UserRole.courier);
    final controller = StreamController<List<Order>>();
    addTearDown(controller.close);
    await pumpApp(
      tester,
      const CourierOrdersScreen(),
      overrides: screenOverrides(
        store,
        orders: _StubOrders(() => controller.stream),
      ),
    );
    expect(find.byKey(const Key('skeleton-list')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('empty shows "No deliveries assigned"', (tester) async {
    final store = testDemoStore(role: UserRole.courier);
    await pumpApp(
      tester,
      const CourierOrdersScreen(),
      overrides: screenOverrides(
        store,
        orders: _StubOrders(() => Stream.value(const <Order>[])),
      ),
    );
    await tester.pump();
    expect(find.text('No deliveries assigned'), findsOneWidget);
    expect(
      find.text('New orders assigned to you will show up here automatically.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('error shows the message and Retry asks again', (tester) async {
    final store = testDemoStore(role: UserRole.courier);
    var calls = 0;
    await pumpApp(
      tester,
      const CourierOrdersScreen(),
      overrides: screenOverrides(
        store,
        orders: _StubOrders(() {
          calls++;
          return calls == 1
              ? Stream<List<Order>>.error(const NetworkError())
              : Stream.value(const <Order>[]);
        }),
      ),
    );
    await tester.pump();
    expect(find.textContaining("You're offline"), findsOneWidget);
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.text('No deliveries assigned'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('shows Assigned and Completed sections with the customer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = testDemoStore(role: UserRole.courier);
    await pumpApp(
      tester,
      const CourierOrdersScreen(),
      overrides: screenOverrides(store),
    );
    await tester.pumpAndSettle();

    expect(find.text('IN PROGRESS'), findsNothing);
    expect(find.text('ASSIGNED'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    for (final code in ['RT-1043', 'RT-1035', 'RT-1029']) {
      expect(find.byKey(Key('order-card-$code')), findsOneWidget);
    }
    expect(find.text('Alex Rivera'), findsWidgets);
    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('order-card-RT-1043'))).dy,
      lessThan(tester.getTopLeft(find.text('COMPLETED')).dy),
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('a new assigned order appears without refreshing, in progress '
      'goes on top', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = testDemoStore(role: UserRole.courier);
    await pumpApp(
      tester,
      const CourierOrdersScreen(),
      overrides: screenOverrides(store),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-card-RT-9999')), findsNothing);

    store.addOrder(
      buildOrder(
        id: 'extra',
        code: 'RT-9999',
        courierId: DemoUsers.courierId,
        customerId: DemoUsers.customerId,
        status: OrderStatus.inTransit,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('order-card-RT-9999'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('order-card-RT-1043'))).dy,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
