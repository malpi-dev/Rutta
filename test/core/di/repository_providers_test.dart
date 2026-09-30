import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/orders/data/mock_connection_monitor.dart';
import 'package:rutta/features/orders/data/mock_orders_repository.dart';
import 'package:rutta/features/tracking/data/mock_device_location_repository.dart';
import 'package:rutta/features/tracking/data/mock_tracking_repository.dart';

void main() {
  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 10, 7))),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('demo mode wires the mock repositories', () {
    final c = container();
    c.read(appModeControllerProvider.notifier).enterDemo(UserRole.customer);
    expect(c.read(ordersRepositoryProvider), isA<MockOrdersRepository>());
    expect(c.read(trackingRepositoryProvider), isA<MockTrackingRepository>());
    expect(c.read(connectionMonitorProvider), isA<MockConnectionMonitor>());
    expect(
      c.read(deviceLocationRepositoryProvider),
      isA<MockDeviceLocationRepository>(),
    );
    expect(c.read(demoStoreProvider).role, UserRole.customer);
  });

  test('changing role creates a new world; leaving disposes the old one', () {
    fakeAsync((async) {
      final c = container();
      final notifier = c.read(appModeControllerProvider.notifier)
        ..enterDemo(UserRole.customer);
      final customerStore = c.read(demoStoreProvider)
        ..ensureCustomerSimulation('demo-order-1042');
      expect(async.pendingTimers, isNotEmpty);

      var customerStoreClosed = false;
      customerStore.changes.listen(
        null,
        onDone: () => customerStoreClosed = true,
      );

      notifier.enterDemo(UserRole.courier);
      final courierStore = c.read(demoStoreProvider);
      async.flushMicrotasks();
      expect(courierStore, isNot(same(customerStore)));
      expect(courierStore.role, UserRole.courier);
      expect(customerStoreClosed, isTrue);
      expect(async.pendingTimers, isEmpty);

      var courierStoreClosed = false;
      courierStore.changes.listen(
        null,
        onDone: () => courierStoreClosed = true,
      );
      notifier.exitDemo();
      final idle = c.read(demoStoreProvider);
      async.flushMicrotasks();
      expect(courierStoreClosed, isTrue);
      expect(idle.ordersForCurrentUser(), isEmpty);
    });
  });
}
