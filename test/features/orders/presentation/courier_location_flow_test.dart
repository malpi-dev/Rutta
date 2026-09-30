import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/presentation/order_detail_screen.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';
import 'package:rutta/features/tracking/presentation/location_publisher.dart';

import '../../../helpers/demo.dart';
import '../../../helpers/location_fakes.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  Future<void> useTallScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    // The spinner while waiting for a fix never settles: pump manually.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  final rt1043 = find.byKey(const Key('order-action-primary'));

  testWidgets('without permission the status still changes, with a warning', (
    tester,
  ) async {
    await useTallScreen(tester);
    final store = testDemoStore(role: UserRole.courier);
    final device = FakeDeviceLocation(access: LocationAccess.denied);
    await pumpApp(
      tester,
      const OrderDetailScreen(
        orderId: 'demo-order-1043',
        role: UserRole.courier,
      ),
      overrides: [
        ...screenOverrides(store, device: device),
        currentRoleProvider.overrideWithValue(UserRole.courier),
        currentUserIdProvider.overrideWithValue(DemoUsers.courierId),
        screenAwakeProvider.overrideWithValue(FakeScreenAwake()),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sharing-indicator')), findsNothing);

    await tester.tap(rt1043);
    await tester.pumpAndSettle();
    expect(find.text('Share your location'), findsOneWidget);

    await tester.tap(find.byKey(const Key('permission-not-now')));
    await settle(tester);
    expect(store.order('demo-order-1043')!.status, OrderStatus.pickedUp);
    expect(
      find.text("Location off — the customer can't see you"),
      findsOneWidget,
    );
    expect(find.text('Enable'), findsOneWidget);
    expect(device.isWatching, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with permission it shares, and Pause / Resume toggle it', (
    tester,
  ) async {
    await useTallScreen(tester);
    final store = testDemoStore(role: UserRole.courier);
    final device = FakeDeviceLocation();
    final awake = FakeScreenAwake();
    await pumpApp(
      tester,
      const OrderDetailScreen(
        orderId: 'demo-order-1043',
        role: UserRole.courier,
      ),
      overrides: [
        ...screenOverrides(store, device: device),
        currentRoleProvider.overrideWithValue(UserRole.courier),
        currentUserIdProvider.overrideWithValue(DemoUsers.courierId),
        screenAwakeProvider.overrideWithValue(awake),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(rt1043);
    await settle(tester);
    expect(find.text('Share your location'), findsNothing);
    expect(find.text('Getting your location…'), findsOneWidget);
    expect(awake.enabled, isTrue);

    device.emit(
      DevicePosition(
        point: store.order('demo-order-1043')!.pickup.point,
        timestamp: store.clock.nowUtc(),
        accuracyMeters: 5,
      ),
    );
    await settle(tester);
    expect(find.text('Sharing location'), findsOneWidget);
    expect(store.location('demo-order-1043'), isNotNull);

    await tester.tap(find.byKey(const Key('sharing-toggle')));
    await settle(tester);
    expect(find.text('Location sharing paused'), findsOneWidget);
    expect(device.isWatching, isFalse);
    expect(awake.enabled, isFalse);

    await tester.tap(find.byKey(const Key('sharing-toggle')));
    await settle(tester);
    expect(find.text('Getting your location…'), findsOneWidget);
    expect(device.isWatching, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the customer never asks for location', (tester) async {
    await useTallScreen(tester);
    final store = testDemoStore();
    final device = FakeDeviceLocation(access: LocationAccess.denied);
    await pumpApp(
      tester,
      const OrderDetailScreen(
        orderId: 'demo-order-1042',
        role: UserRole.customer,
      ),
      overrides: [
        ...screenOverrides(store, device: device),
        currentRoleProvider.overrideWithValue(UserRole.customer),
        currentUserIdProvider.overrideWithValue(DemoUsers.customerId),
      ],
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(device.checkCalls, 0);
    expect(device.requestCalls, 0);
    expect(find.byKey(const Key('sharing-indicator')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
