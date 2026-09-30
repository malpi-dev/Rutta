import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/config/env.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/features/demo/data/demo_store.dart';
import 'package:rutta/features/orders/data/mock_connection_monitor.dart';
import 'package:rutta/features/orders/data/mock_orders_repository.dart';
import 'package:rutta/features/orders/domain/available_order_actions.dart';
import 'package:rutta/features/orders/domain/connection_monitor.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';
import 'package:rutta/features/settings/data/prefs_settings_repository.dart';
import 'package:rutta/features/settings/domain/settings_repository.dart';
import 'package:rutta/features/tracking/data/mock_device_location_repository.dart';
import 'package:rutta/features/tracking/data/mock_tracking_repository.dart';
import 'package:rutta/features/tracking/domain/compute_route_progress.dart';
import 'package:rutta/features/tracking/domain/device_location_repository.dart';
import 'package:rutta/features/tracking/domain/should_send_location.dart';
import 'package:rutta/features/tracking/domain/tracking_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'repository_providers.g.dart';

/// Composition root: the only file (besides `main.dart`) that wires `data/`
/// implementations of several features.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError(
  'sharedPreferencesProvider must be overridden in main()',
);

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    PrefsSettingsRepository(ref.watch(sharedPreferencesProvider));

/// In-memory world of the demo. Entering or leaving the demo rebuilds it, so
/// every visit starts from a fresh world and the old one is disposed.
@Riverpod(keepAlive: true)
DemoStore demoStore(Ref ref) {
  final clock = ref.watch(clockProvider);
  final store = switch (ref.watch(appModeControllerProvider)) {
    AppModeDemo(:final role) => DemoStore.seeded(role: role, clock: clock),
    AppModeLive() => DemoStore.idle(clock: clock),
  };
  ref.onDispose(store.dispose);
  return store;
}

// The live branches are temporary and unreachable: without a session the
// router sends the user to the login screen.
@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppModeLive() => throw UnimplementedError(
        'SupabaseOrdersRepository arrives in phase 11',
      ),
      AppModeDemo() => MockOrdersRepository(ref.watch(demoStoreProvider)),
    };

@Riverpod(keepAlive: true)
TrackingRepository trackingRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppModeLive() => throw UnimplementedError(
        'SupabaseTrackingRepository arrives in phase 11',
      ),
      AppModeDemo() => MockTrackingRepository(ref.watch(demoStoreProvider)),
    };

@Riverpod(keepAlive: true)
ConnectionMonitor connectionMonitor(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppModeLive() => throw UnimplementedError(
        'SupabaseConnectionMonitor arrives in phase 11',
      ),
      AppModeDemo() => MockConnectionMonitor(),
    };

@Riverpod(keepAlive: true)
DeviceLocationRepository deviceLocationRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppModeLive() => throw UnimplementedError(
        'GeolocatorDeviceLocationRepository arrives in phase 08',
      ),
      AppModeDemo() => MockDeviceLocationRepository(
        ref.watch(demoStoreProvider),
      ),
    };

@Riverpod(keepAlive: true)
ComputeRouteProgress computeRouteProgress(Ref ref) =>
    const ComputeRouteProgress();

@Riverpod(keepAlive: true)
AvailableOrderActions availableOrderActions(Ref ref) =>
    const AvailableOrderActions();

@Riverpod(keepAlive: true)
ShouldSendLocation shouldSendLocation(Ref ref) => ShouldSendLocation(
  minInterval: Env.locationMinInterval,
  minDistanceMeters: Env.locationMinDistanceMeters,
);
