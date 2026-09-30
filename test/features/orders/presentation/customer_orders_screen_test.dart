import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';
import 'package:rutta/features/orders/presentation/customer_orders_screen.dart';

import '../../../helpers/demo.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_overrides.dart';

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
    final store = testDemoStore();
    final controller = StreamController<List<Order>>();
    addTearDown(controller.close);
    await pumpApp(
      tester,
      const CustomerOrdersScreen(),
      overrides: screenOverrides(
        store,
        orders: _StubOrders(() => controller.stream),
      ),
    );
    expect(find.byKey(const Key('skeleton-list')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('empty shows the empty state with the live hint', (tester) async {
    final store = testDemoStore();
    await pumpApp(
      tester,
      const CustomerOrdersScreen(),
      overrides: screenOverrides(
        store,
        orders: _StubOrders(() => Stream.value(const <Order>[])),
      ),
    );
    await tester.pump();
    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.textContaining('Explore demo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('error shows the message and Retry asks again', (tester) async {
    final store = testDemoStore();
    var calls = 0;
    await pumpApp(
      tester,
      const CustomerOrdersScreen(),
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
    expect(find.text('No orders yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('data is split into Active and History', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = testDemoStore();
    await pumpApp(
      tester,
      const CustomerOrdersScreen(),
      overrides: screenOverrides(store),
    );
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
    for (final code in [
      'RT-1042',
      'RT-1043',
      'RT-1038',
      'RT-1035',
      'RT-1031',
    ]) {
      expect(find.byKey(Key('order-card-$code')), findsOneWidget);
    }
    expect(find.byKey(const Key('order-card-RT-1029')), findsNothing);
    final historyY = tester.getTopLeft(find.text('HISTORY')).dy;
    expect(
      tester.getTopLeft(find.byKey(const Key('order-card-RT-1043'))).dy,
      lessThan(historyY),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('order-card-RT-1038'))).dy,
      greaterThan(historyY),
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'tapping a card opens the detail and a delivery moves the order to History',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: noAutomaticRetry,
          overrides: testOverrides(),
          child: const RuttaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('login-explore-demo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-as-customer')));
      await tester.pumpAndSettle();

      // Live update without refreshing: RT-1042 is delivered by the system.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerOrdersScreen)),
      );
      final store = container.read(demoStoreProvider);
      double y(String code) =>
          tester.getTopLeft(find.byKey(Key('order-card-$code'))).dy;
      final historyBefore = tester.getTopLeft(find.text('HISTORY')).dy;
      expect(y('RT-1042'), lessThan(historyBefore));
      store.advance(
        'demo-order-1042',
        OrderStatus.delivered,
        actorId: DemoUsers.otherCourierId,
        asSystem: true,
      );
      await tester.pumpAndSettle();
      expect(
        y('RT-1042'),
        greaterThan(tester.getTopLeft(find.text('HISTORY')).dy),
      );
      expect(
        y('RT-1043'),
        lessThan(tester.getTopLeft(find.text('HISTORY')).dy),
      );

      await tester.tap(find.byKey(const Key('order-card-RT-1043')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-status-headline')), findsOneWidget);
      expect(find.text('Courier assigned'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
