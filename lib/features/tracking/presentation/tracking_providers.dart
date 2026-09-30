import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/domain/route_progress.dart';
import 'package:rutta/features/tracking/presentation/location_publisher.dart';

part 'tracking_providers.g.dart';

@riverpod
Stream<CourierLocation?> courierLocation(Ref ref, String orderId) =>
    ref.watch(trackingRepositoryProvider).watchCourierLocation(orderId);

/// The courier position drawn on the map of [orderId]. Customer: the location
/// published by the courier. Courier: their own GPS fix, straight from the
/// publisher (no round trip through the backend).
@riverpod
AsyncValue<CourierLocation?> displayedCourierLocation(
  Ref ref,
  String orderId,
  UserRole role,
) {
  if (role == UserRole.customer) {
    return ref.watch(courierLocationProvider(orderId));
  }
  final sharing = ref.watch(locationSharingStateProvider).value;
  final fix = sharing?.lastPosition;
  if (sharing == null || sharing.orderId != orderId || fix == null) {
    return const AsyncData(null);
  }
  return AsyncData(
    CourierLocation(
      courierId: ref.watch(currentUserIdProvider) ?? '',
      orderId: orderId,
      point: fix.point,
      recordedAt: fix.timestamp,
      heading: fix.heading,
      speedMps: fix.speedMps,
      accuracyMeters: fix.accuracyMeters,
    ),
  );
}

/// Ticks once per second so "Last updated X s ago" and the stale state
/// refresh without new data.
@riverpod
Stream<DateTime> now(Ref ref) {
  final clock = ref.watch(clockProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) => clock.nowUtc());
}

/// Progress of the courier over the route. null when there is no location yet.
@riverpod
RouteProgress? routeProgress(Ref ref, String orderId, UserRole role) {
  final order = ref.watch(orderProvider(orderId)).value;
  final location = ref
      .watch(displayedCourierLocationProvider(orderId, role))
      .value;
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
