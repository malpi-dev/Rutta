import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/map/rutta_map_provider.dart';
import 'package:rutta/features/demo/data/demo_store.dart';
import 'package:rutta/features/orders/data/mock_connection_monitor.dart';
import 'package:rutta/features/orders/data/mock_orders_repository.dart';
import 'package:rutta/features/orders/domain/connection_monitor.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';
import 'package:rutta/features/tracking/data/mock_device_location_repository.dart';
import 'package:rutta/features/tracking/data/mock_tracking_repository.dart';
import 'package:rutta/features/tracking/domain/device_location_repository.dart';
import 'package:rutta/features/tracking/domain/tracking_repository.dart';

import 'fake_rutta_map.dart';

/// Overrides for screen tests: mock repositories over [store], the fake map
/// and the clock shared with the store. Individual repositories can be
/// replaced.
List<Override> screenOverrides(
  DemoStore store, {
  OrdersRepository? orders,
  TrackingRepository? tracking,
  DeviceLocationRepository? device,
  ConnectionMonitor? connection,
}) => [
  clockProvider.overrideWithValue(store.clock),
  ordersRepositoryProvider.overrideWithValue(
    orders ?? MockOrdersRepository(store),
  ),
  trackingRepositoryProvider.overrideWithValue(
    tracking ?? MockTrackingRepository(store),
  ),
  deviceLocationRepositoryProvider.overrideWithValue(
    device ?? MockDeviceLocationRepository(store),
  ),
  connectionMonitorProvider.overrideWithValue(
    connection ?? MockConnectionMonitor(),
  ),
  ruttaMapBuilderProvider.overrideWithValue(FakeRuttaMap.new),
];

/// Same as [screenOverrides] with a bare clock (no store).
List<Override> mapOverrides(
  Clock clock, {
  required TrackingRepository tracking,
}) => [
  clockProvider.overrideWithValue(clock),
  trackingRepositoryProvider.overrideWithValue(tracking),
  ruttaMapBuilderProvider.overrideWithValue(FakeRuttaMap.new),
];

/// Lets chained zero-delay timers and provider notifications run (order loads,
/// then the location subscription starts, then the first location arrives).
Future<void> pumpUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}
