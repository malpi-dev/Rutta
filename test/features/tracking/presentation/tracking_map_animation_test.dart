import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/map/rutta_map.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/domain/tracking_repository.dart';
import 'package:rutta/features/tracking/presentation/tracking_map.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/fake_rutta_map.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/pump_app.dart';

class _ControlledTracking implements TrackingRepository {
  final controller = StreamController<CourierLocation?>();

  @override
  Stream<CourierLocation?> watchCourierLocation(String orderId) =>
      controller.stream;

  @override
  Future<void> publishLocation(CourierLocation location) async {}
}

GeoPoint displayed() =>
    FakeRuttaMap.lastProps!.markers.singleWhere((m) => m.id == 'courier').point;

void main() {
  final t0 = DateTime.utc(2026, 10, 7, 18);
  late _ControlledTracking tracking;

  CourierLocation at(GeoPoint point, int seconds) => CourierLocation(
    courierId: 'k1',
    orderId: 'o1',
    point: point,
    recordedAt: t0.add(Duration(seconds: seconds)),
  );

  setUp(() => tracking = _ControlledTracking());
  tearDown(() => unawaited(tracking.controller.close()));

  Future<void> pumpMap(WidgetTester tester) => pumpApp(
    tester,
    Scaffold(
      body: TrackingMap(
        order: buildOrder(status: OrderStatus.inTransit),
        role: UserRole.customer,
        controller: RuttaMapController(),
      ),
    ),
    overrides: mapOverrides(FixedClock(t0), tracking: tracking),
  );

  Future<void> emit(WidgetTester tester, CourierLocation? location) async {
    tracking.controller.add(location);
    await tester.pump(); // delivers the event and starts the animation
    await tester.pump(); // the ticker takes its start time on this frame
  }

  testWidgets('glides along the route between two locations', (tester) async {
    await pumpMap(tester);
    expect(find.byKey(const Key('marker-courier')), findsNothing);

    await emit(tester, at(const GeoPoint(0, 0.001), 0));
    // First location is placed without animating.
    expect(displayed().lng, closeTo(0.001, 1e-9));

    await emit(tester, at(const GeoPoint(0, 0.011), 2));
    await tester.pump(const Duration(seconds: 1));
    final mid = displayed();
    expect(mid.lat, closeTo(0, 1e-9)); // on the route
    expect(mid.lng, closeTo(0.006, 1e-4)); // halfway
    expect(FakeRuttaMap.lastProps!.polylines.map((p) => p.id), [
      'traveled',
      'remaining',
    ]);

    await tester.pump(const Duration(seconds: 1));
    expect(displayed().lng, closeTo(0.011, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with disableAnimations the marker jumps to the new location', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpMap(tester);
    await emit(tester, at(const GeoPoint(0, 0.001), 0));
    await emit(tester, at(const GeoPoint(0, 0.011), 2));
    expect(displayed().lng, closeTo(0.011, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('follows the bends of the route instead of cutting corners', (
    tester,
  ) async {
    const bent = [GeoPoint(0, 0), GeoPoint(0, 0.01), GeoPoint(0.01, 0.01)];
    await pumpApp(
      tester,
      Scaffold(
        body: TrackingMap(
          order: buildOrder(status: OrderStatus.inTransit, route: bent),
          role: UserRole.customer,
          controller: RuttaMapController(),
        ),
      ),
      overrides: mapOverrides(FixedClock(t0), tracking: tracking),
    );
    await emit(tester, at(const GeoPoint(0, 0.008), 0));
    await emit(tester, at(const GeoPoint(0.004, 0.01), 4));
    await tester.pump(const Duration(seconds: 2));
    final mid = displayed();
    // Halfway (1223 route meters) is 111 m past the corner, on the second leg;
    // the straight line between both locations would be at lng 0.009.
    expect(mid.lng, closeTo(0.01, 1e-9));
    expect(mid.lat, closeTo(0.001, 1e-4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an off-route location is shown at its real position', (
    tester,
  ) async {
    await pumpMap(tester);
    await emit(tester, at(const GeoPoint(0, 0.005), 0));
    // ~111 m north of the route: beyond the 75 m threshold.
    await emit(tester, at(const GeoPoint(0.001, 0.005), 2));
    await tester.pump(const Duration(seconds: 3));
    final p = displayed();
    expect(p.lat, closeTo(0.001, 1e-9));
    expect(p.lng, closeTo(0.005, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a null location removes the marker', (tester) async {
    await pumpMap(tester);
    await emit(tester, at(const GeoPoint(0, 0.005), 0));
    expect(find.byKey(const Key('marker-courier')), findsOneWidget);
    await emit(tester, null);
    expect(find.byKey(const Key('marker-courier')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
