import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/domain/route_progress.dart';

part 'tracking_providers.g.dart';

@riverpod
Stream<CourierLocation?> courierLocation(Ref ref, String orderId) =>
    ref.watch(trackingRepositoryProvider).watchCourierLocation(orderId);

/// Ticks once per second so "Last updated X s ago" and the stale state
/// refresh without new data.
@riverpod
Stream<DateTime> now(Ref ref) {
  final clock = ref.watch(clockProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) => clock.nowUtc());
}

/// Progress of the courier over the route. null when there is no location yet.
@riverpod
RouteProgress? routeProgress(Ref ref, String orderId) {
  final order = ref.watch(orderProvider(orderId)).value;
  final location = ref.watch(courierLocationProvider(orderId)).value;
  if (order == null || location == null) return null;
  return ref.watch(computeRouteProgressProvider)(
    route: order.route,
    position: location.point,
    speedMps: location.speedMps,
  );
}

/// Whether the last known courier location is stale. Depends on [now], but
/// listeners are only notified when the boolean flips (no per-second rebuilds).
@riverpod
bool isCourierLocationStale(Ref ref, String orderId) {
  final location = ref.watch(courierLocationProvider(orderId)).value;
  if (location == null) return false;
  final now = ref.watch(nowProvider).value ?? ref.watch(clockProvider).nowUtc();
  return location.isStale(now);
}
