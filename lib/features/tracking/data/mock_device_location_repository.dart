import 'dart:async';

import 'package:collection/collection.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/demo/data/demo_store.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/data/demo_courier_simulator.dart';
import 'package:rutta/features/tracking/domain/device_location_repository.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

/// Replaces the GPS in demo mode (works on emulators and in airplane mode).
class MockDeviceLocationRepository implements DeviceLocationRepository {
  MockDeviceLocationRepository(this._store);

  static const _repeat = Duration(seconds: 5);

  final DemoStore _store;

  @override
  Future<LocationAccess> checkAccess() async => LocationAccess.granted;

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.granted;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Stream<DevicePosition> watchPosition() {
    StreamSubscription<void>? changes;
    // ignore: cancel_subscriptions, cancelled in stopCurrent() (onCancel).
    StreamSubscription<DevicePosition>? simulation;
    Timer? repeater;
    String? currentKey;
    late final StreamController<DevicePosition> controller;

    Future<void> stopCurrent() async {
      repeater?.cancel();
      repeater = null;
      final sim = simulation;
      simulation = null;
      await sim?.cancel();
    }

    void repeatEvery(Order order, GeoPoint Function(Order) at) {
      void emit() => controller.add(
        DevicePosition(
          point: at(order),
          timestamp: _store.clock.nowUtc(),
          speedMps: 0,
          accuracyMeters: 5,
        ),
      );
      emit();
      repeater = Timer.periodic(_repeat, (_) => emit());
    }

    Future<void> evaluate() async {
      final order = _store.ordersForCurrentUser().firstWhereOrNull(
        (o) => o.status.isInProgress,
      );
      final key = order == null ? null : '${order.id}:${order.status.wireName}';
      if (key == currentKey) return;
      currentKey = key;
      await stopCurrent();
      if (order == null) return;
      if (order.status == OrderStatus.pickedUp) {
        repeatEvery(order, (o) => o.pickup.point);
      } else {
        simulation =
            DemoCourierSimulator(
              route: order.route,
              clock: _store.clock,
              targetDuration: _store.simulationDuration,
              tick: _store.simulationTick,
            ).positions().listen(
              controller.add,
              onDone: () => repeatEvery(order, (o) => o.route.last),
            );
      }
    }

    controller = StreamController<DevicePosition>(
      onListen: () {
        unawaited(evaluate());
        changes = _store.changes.listen((_) => unawaited(evaluate()));
      },
      onCancel: () async {
        // Stop the timers first: cancelling a subscription can take a while.
        final stopping = stopCurrent();
        await changes?.cancel();
        await stopping;
      },
    );
    return controller.stream;
  }
}
