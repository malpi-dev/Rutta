import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/orders/presentation/order_detail_screen.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/domain/tracking_repository.dart';
import 'package:rutta/features/tracking/presentation/widgets/map_pins.dart';

import '../../../helpers/demo.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/pump_app.dart';

class _FixedTracking implements TrackingRepository {
  _FixedTracking(this.location);

  final CourierLocation location;

  @override
  Stream<CourierLocation?> watchCourierLocation(String orderId) =>
      Stream.value(location);

  @override
  Future<void> publishLocation(CourierLocation location) async {}
}

void main() {
  Future<void> pumpWithAge(WidgetTester tester, Duration age) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 7, 18));
    final store = testDemoStore(clock: clock);
    addTearDown(store.dispose);
    final order = store.order('demo-order-1042')!;
    final location = CourierLocation(
      courierId: order.courierId!,
      orderId: order.id,
      point: order.route[order.route.length ~/ 2],
      recordedAt: clock.nowUtc().subtract(age),
    );
    await pumpApp(
      tester,
      const OrderDetailScreen(
        orderId: 'demo-order-1042',
        role: UserRole.customer,
      ),
      overrides: screenOverrides(store, tracking: _FixedTracking(location)),
    );
    await pumpUntilLoaded(tester);
  }

  testWidgets('45 s old location shows the stale notice and a grey pin', (
    tester,
  ) async {
    await pumpWithAge(tester, const Duration(seconds: 45));

    expect(find.byKey(const Key('stale-indicator')), findsOneWidget);
    expect(find.text('Last updated 45 s ago'), findsOneWidget);
    expect(tester.widget<CourierPin>(find.byType(CourierPin)).stale, isTrue);
    // Stale is shown, never hidden.
    expect(find.byKey(const Key('marker-courier')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('10 s old location is fresh', (tester) async {
    await pumpWithAge(tester, const Duration(seconds: 10));

    expect(find.byKey(const Key('stale-indicator')), findsNothing);
    expect(tester.widget<CourierPin>(find.byType(CourierPin)).stale, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
