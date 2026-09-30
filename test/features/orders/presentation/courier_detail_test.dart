import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/demo/data/demo_store.dart';
import 'package:rutta/features/orders/data/mock_orders_repository.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';
import 'package:rutta/features/orders/presentation/order_detail_screen.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/demo.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/pump_app.dart';

/// Delegates to the mock but lets the test decide when/if advancing fails.
class _ControlledOrders implements OrdersRepository {
  _ControlledOrders(DemoStore store) : _inner = MockOrdersRepository(store);

  final MockOrdersRepository _inner;
  Completer<void>? gate;
  DomainError? failWith;

  @override
  Stream<List<Order>> watchMyOrders() => _inner.watchMyOrders();

  @override
  Stream<Order> watchOrder(String orderId) => _inner.watchOrder(orderId);

  @override
  Stream<List<OrderStatusEvent>> watchStatusEvents(String orderId) =>
      _inner.watchStatusEvents(orderId);

  @override
  Future<Order> advanceStatus(String orderId, OrderStatus next) async {
    await gate?.future;
    if (failWith case final error?) throw error;
    return _inner.advanceStatus(orderId, next);
  }
}

Widget detail() => const OrderDetailScreen(
  orderId: 'demo-order-1043',
  role: UserRole.courier,
);

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  Future<void> useTallScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('walks RT-1043 from assigned to delivered', (tester) async {
    await useTallScreen(tester);
    final store = testDemoStore(role: UserRole.courier);
    await pumpApp(tester, detail(), overrides: screenOverrides(store));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('order-action-primary'));
    expect(
      find.descendant(of: button, matching: find.text('Picked up')),
      findsOneWidget,
    );
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('Your courier'), findsNothing);
    expect(find.byKey(const Key('marker-courier')), findsNothing);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: button, matching: find.text('Start delivery')),
      findsOneWidget,
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: button, matching: find.text('Mark as delivered')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('marker-courier')), findsNothing);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Mark as delivered?'), findsOneWidget);
    expect(
      find.text('Confirm that you handed order RT-1043 to the customer.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as delivered?'), findsNothing);
    expect(
      find.descendant(of: button, matching: find.text('Mark as delivered')),
      findsOneWidget,
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delivered')));
    await tester.pumpAndSettle();

    expect(button, findsNothing);
    expect(find.byKey(const Key('order-status-headline')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('order-status-headline'))).data,
      'Delivered',
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('timeline-delivered')))
          .opacity,
      1,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('the button is disabled with a spinner while loading', (
    tester,
  ) async {
    final store = testDemoStore(role: UserRole.courier);
    final orders = _ControlledOrders(store)..gate = Completer<void>();
    await pumpApp(
      tester,
      detail(),
      overrides: screenOverrides(store, orders: orders),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('order-action-primary'));
    await tester.tap(button);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    orders.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('a typed error shows a SnackBar and keeps the button', (
    tester,
  ) async {
    final store = testDemoStore(role: UserRole.courier);
    final orders = _ControlledOrders(store)
      ..failWith = const InvalidTransitionError(
        from: 'assigned',
        to: 'picked_up',
      );
    await pumpApp(
      tester,
      detail(),
      overrides: screenOverrides(store, orders: orders),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('order-action-primary'));
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text("This order can't move to that status."), findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.text('Picked up')),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('another order in progress blocks Picked up', (tester) async {
    await useTallScreen(tester);
    final store = testDemoStore(role: UserRole.courier)
      ..addOrder(
        buildOrder(
          id: 'extra',
          code: 'RT-9999',
          courierId: DemoUsers.courierId,
          customerId: DemoUsers.customerId,
          status: OrderStatus.pickedUp,
        ),
      );
    await pumpApp(tester, detail(), overrides: screenOverrides(store));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('order-action-primary'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      find.text('Finish your current delivery before starting another one.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('the customer never sees the primary action', (tester) async {
    final store = testDemoStore();
    await pumpApp(
      tester,
      const OrderDetailScreen(
        orderId: 'demo-order-1043',
        role: UserRole.customer,
      ),
      overrides: screenOverrides(store),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-action-primary')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
