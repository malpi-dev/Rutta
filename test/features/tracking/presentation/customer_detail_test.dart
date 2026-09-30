import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/map/rutta_map.dart';
import 'package:rutta/features/orders/presentation/order_detail_screen.dart';

import '../../../helpers/demo.dart';
import '../../../helpers/fake_rutta_map.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/pump_app.dart';

class _FakeDelegate implements RuttaMapDelegate {
  GeoPoint? centeredOn;
  double? zoom;

  @override
  void centerOn(GeoPoint point, {double? zoom}) {
    centeredOn = point;
    this.zoom = zoom;
  }

  @override
  void fitPoints(
    List<GeoPoint> points, {
    EdgeInsets padding = EdgeInsets.zero,
  }) {}
}

GeoPoint? courierPoint() {
  final markers = FakeRuttaMap.lastProps!.markers.where(
    (m) => m.id == 'courier',
  );
  return markers.isEmpty ? null : markers.single.point;
}

void main() {
  testWidgets('assigned order: no courier marker, tracking starts on pickup', (
    tester,
  ) async {
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

    expect(find.byKey(const Key('marker-courier')), findsNothing);
    expect(find.byKey(const Key('marker-pickup')), findsOneWidget);
    expect(find.byKey(const Key('tracking-recenter')), findsNothing);
    expect(find.text('Courier assigned'), findsWidgets);
    expect(
      find.text('Tracking starts when the courier picks up your order'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('in transit order: marker, ETA and distance; ends delivered', (
    tester,
  ) async {
    // Tall screen so the whole panel (down to the timeline) is built.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = testDemoStore();
    await pumpApp(
      tester,
      const OrderDetailScreen(
        orderId: 'demo-order-1042',
        role: UserRole.customer,
      ),
      overrides: screenOverrides(store),
    );
    await pumpUntilLoaded(tester);

    expect(find.byKey(const Key('marker-courier')), findsOneWidget);
    expect(find.byKey(const Key('tracking-eta')), findsOneWidget);
    final distance = find.byKey(const Key('tracking-distance'));
    expect(distance, findsOneWidget);
    final firstText = tester.widget<Text>(distance).data;
    final firstPoint = courierPoint()!;
    expect(find.text('In transit'), findsWidgets);
    expect(find.textContaining('left'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<Text>(distance).data, isNot(firstText));
    final laterPoint = courierPoint()!;
    expect(laterPoint, isNot(firstPoint));
    expect(laterPoint.lng, isNot(firstPoint.lng));

    // The 5 s test simulation ends and the system delivers the order.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('marker-courier')), findsNothing);
    expect(find.byKey(const Key('tracking-eta')), findsNothing);
    expect(find.text('Delivered'), findsWidgets);
    expect(find.textContaining('Delivered at'), findsOneWidget);
    expect(find.byKey(const Key('timeline-delivered')), findsOneWidget);
    final deliveredRow = find.byKey(const Key('timeline-delivered'));
    expect(
      tester.widget<Opacity>(deliveredRow).opacity,
      1,
    );
    expect(
      find.descendant(
        of: deliveredRow,
        matching: find.textContaining(RegExp('[AP]M')),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('unknown order shows "no longer exists" with Retry', (
    tester,
  ) async {
    final store = testDemoStore();
    await pumpApp(
      tester,
      const OrderDetailScreen(orderId: 'nope', role: UserRole.customer),
      overrides: screenOverrides(store),
    );
    await tester.pumpAndSettle();
    expect(find.text('This order no longer exists.'), findsOneWidget);
    expect(find.byKey(const Key('error-retry')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('recenter button centers the map on the courier', (tester) async {
    final store = testDemoStore();
    await pumpApp(
      tester,
      const OrderDetailScreen(
        orderId: 'demo-order-1042',
        role: UserRole.customer,
      ),
      overrides: screenOverrides(store),
    );
    await pumpUntilLoaded(tester);

    final delegate = _FakeDelegate();
    FakeRuttaMap.lastProps!.controller!.attach(delegate);
    await tester.tap(find.byKey(const Key('tracking-recenter')));
    await tester.pump();

    expect(delegate.centeredOn, courierPoint());
    expect(delegate.zoom, 16);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
