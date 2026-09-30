import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/tracking/presentation/location_publisher_engine.dart';
import 'package:rutta/features/tracking/presentation/screen_awake.dart';

part 'location_publisher.g.dart';

/// Courier only: the order currently in picked_up / in_transit, if any.
@riverpod
Order? activeDelivery(Ref ref) {
  if (ref.watch(currentRoleProvider) != UserRole.courier) return null;
  final orders = ref.watch(myOrdersProvider).value ?? const <Order>[];
  return orders.firstWhereOrNull((o) => o.status.isInProgress);
}

@Riverpod(keepAlive: true)
ScreenAwake screenAwake(Ref ref) => WakelockScreenAwake();

/// Rebuilt when the repositories or the user change (mode switch, sign-out).
@Riverpod(keepAlive: true)
LocationPublisherEngine locationPublisher(Ref ref) {
  final engine = LocationPublisherEngine(
    device: ref.watch(deviceLocationRepositoryProvider),
    tracking: ref.watch(trackingRepositoryProvider),
    shouldSend: ref.watch(shouldSendLocationProvider),
    clock: ref.watch(clockProvider),
    screenAwake: ref.watch(screenAwakeProvider),
    courierId: ref.watch(currentUserIdProvider) ?? '',
  );
  final lifecycle = AppLifecycleListener(
    onPause: engine.onAppPaused,
    onHide: engine.onAppPaused,
    onResume: engine.onAppResumed,
  );
  ref
    ..listen(
      activeDeliveryProvider,
      (_, next) => unawaited(engine.setActiveOrder(next)),
    )
    ..onDispose(() {
      lifecycle.dispose();
      engine.dispose();
    });
  unawaited(engine.setActiveOrder(ref.read(activeDeliveryProvider)));
  return engine;
}

@riverpod
Stream<LocationSharingState> locationSharingState(Ref ref) =>
    ref.watch(locationPublisherProvider).states;
