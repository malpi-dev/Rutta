// Gaps of the UI-state audit (definition 12.1) that no feature test covers:
// startup loading/error, detail loading and "created" order, reconnecting
// banner in the lists and detail screens. The rest of the table lives in the
// feature tests (lists, detail, auth, settings).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/auth/data/mock_auth_repository.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/orders/data/mock_connection_monitor.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';
import 'package:rutta/features/orders/presentation/courier_orders_screen.dart';
import 'package:rutta/features/orders/presentation/customer_orders_screen.dart';
import 'package:rutta/features/orders/presentation/order_detail_screen.dart';

import '../features/auth/presentation/auth_test_helpers.dart';
import '../helpers/builders.dart';
import '../helpers/demo.dart';
import '../helpers/order_overrides.dart';
import '../helpers/pump_app.dart';
import '../helpers/test_overrides.dart';

class _ScriptedAuth extends MockAuthRepository {
  _ScriptedAuth(this.streams);

  final List<Stream<SessionState>> streams;
  int watches = 0;

  @override
  Stream<SessionState> watchSession() => streams[watches++];
}

class _StubOrders extends MockOrdersRepositoryBase {
  _StubOrders({this.order, this.list});

  final Stream<Order>? order;
  final Stream<List<Order>>? list;

  @override
  Stream<List<Order>> watchMyOrders() => list ?? const Stream.empty();

  @override
  Stream<Order> watchOrder(String orderId) => order ?? const Stream.empty();

  @override
  Stream<List<OrderStatusEvent>> watchStatusEvents(String orderId) =>
      Stream.value(const []);
}

abstract class MockOrdersRepositoryBase implements OrdersRepository {
  @override
  Future<Order> advanceStatus(String orderId, OrderStatus next) =>
      throw UnimplementedError();
}

void main() {
  group('Startup', () {
    Future<void> pumpStartup(WidgetTester tester, MockAuthRepository auth) =>
        tester.pumpWidget(
          ProviderScope(
            retry: noAutomaticRetry,
            overrides: [...testOverrides(), ...authOverrides(auth)],
            child: const RuttaApp(),
          ),
        );

    testWidgets('shows a spinner while the session loads', (tester) async {
      final pending = StreamController<SessionState>();
      addTearDown(pending.close);
      await pumpStartup(tester, _ScriptedAuth([pending.stream]));
      await tester.pump();
      expect(find.byKey(const Key('startup-loading')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an error shows the message and Retry asks again', (
      tester,
    ) async {
      final auth = _ScriptedAuth([
        Stream.error(const NetworkError()),
        Stream.value(const SessionSignedOut()),
      ]);
      await pumpStartup(tester, auth);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('error-retry')), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsNothing);

      await tester.tap(find.byKey(const Key('error-retry')));
      await tester.pumpAndSettle();
      expect(auth.watches, 2);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Customer detail', () {
    testWidgets('loading shows the skeleton', (tester) async {
      final store = testDemoStore();
      final pending = StreamController<Order>();
      addTearDown(pending.close);
      await pumpApp(
        tester,
        const OrderDetailScreen(orderId: 'o1', role: UserRole.customer),
        overrides: screenOverrides(
          store,
          orders: _StubOrders(order: pending.stream),
        ),
      );
      expect(find.byType(OrderDetailSkeleton), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('created order: "Waiting for a courier"', (tester) async {
      final store = testDemoStore();
      await pumpApp(
        tester,
        const OrderDetailScreen(orderId: 'o1', role: UserRole.customer),
        overrides: screenOverrides(
          store,
          orders: _StubOrders(
            order: Stream.value(
              buildOrder(status: OrderStatus.created, courierId: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Waiting for a courier'), findsWidgets);
      expect(find.byKey(const Key('marker-courier')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  });

  group('Courier detail', () {
    testWidgets('unknown order shows "no longer exists" with Retry', (
      tester,
    ) async {
      final store = testDemoStore(role: UserRole.courier);
      await pumpApp(
        tester,
        const OrderDetailScreen(orderId: 'nope', role: UserRole.courier),
        overrides: screenOverrides(store),
      );
      await tester.pumpAndSettle();
      expect(find.text('This order no longer exists.'), findsOneWidget);
      expect(find.byKey(const Key('error-retry')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  });

  group('Reconnecting banner', () {
    for (final (name, screen) in <(String, Widget)>[
      ('customer list', const CustomerOrdersScreen()),
      ('courier list', const CourierOrdersScreen()),
      (
        'order detail',
        const OrderDetailScreen(orderId: 'o1', role: UserRole.customer),
      ),
    ]) {
      testWidgets('is shown by the $name while disconnected', (tester) async {
        final store = testDemoStore();
        final connection = StreamController<bool>();
        addTearDown(connection.close);
        await pumpApp(
          tester,
          screen,
          overrides: [
            ...screenOverrides(
              store,
              orders: _StubOrders(
                order: Stream.value(buildOrder()),
                list: Stream.value(const []),
              ),
              connection: MockConnectionMonitor.controlled(connection),
            ),
          ],
        );
        connection.add(false);
        await pumpUntilLoaded(tester);
        expect(find.byKey(const Key('reconnecting-banner')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      });
    }
  });
}
