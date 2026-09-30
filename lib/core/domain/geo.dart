import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rutta/core/domain/geo_point.dart';

const earthRadiusMeters = 6371000.0;

double _rad(double deg) => deg * math.pi / 180;

/// Great-circle distance in meters.
double haversineMeters(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Initial bearing from [a] to [b] in degrees, 0..360 (0 = north, 90 = east).
double bearingDegrees(GeoPoint a, GeoPoint b) {
  final phi1 = _rad(a.lat);
  final phi2 = _rad(b.lat);
  final dLng = _rad(b.lng - a.lng);
  final y = math.sin(dLng) * math.cos(phi2);
  final x =
      math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// Sum of the haversine lengths of every segment. 0 for fewer than 2 points.
double routeLengthMeters(List<GeoPoint> route) {
  var total = 0.0;
  for (var i = 0; i < route.length - 1; i++) {
    total += haversineMeters(route[i], route[i + 1]);
  }
  return total;
}

@immutable
class RouteProjection {
  const RouteProjection({
    required this.snappedPoint,
    required this.segmentIndex,
    required this.distanceToRouteMeters,
    required this.traveledMeters,
  });

  /// Closest point on the polyline.
  final GeoPoint snappedPoint;

  /// Segment `i` goes from `route[i]` to `route[i + 1]`.
  final int segmentIndex;
  final double distanceToRouteMeters;

  /// Along the route, from `route[0]` to [snappedPoint].
  final double traveledMeters;
}

/// Projects [point] on the closest segment of [route] (>= 2 points, otherwise
/// [ArgumentError]).
RouteProjection projectOntoRoute(List<GeoPoint> route, GeoPoint point) {
  if (route.length < 2) {
    throw ArgumentError.value(route, 'route', 'needs at least 2 points');
  }
  final k = math.cos(_rad(point.lat));
  final px = point.lng * k;
  final py = point.lat;

  var bestIndex = 0;
  var bestDistance = double.infinity;
  late GeoPoint bestPoint;
  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i];
    final b = route[i + 1];
    final ax = a.lng * k;
    final ay = a.lat;
    final dx = b.lng * k - ax;
    final dy = b.lat - ay;
    final lenSq = dx * dx + dy * dy;
    final t = lenSq == 0
        ? 0.0
        : (((px - ax) * dx + (py - ay) * dy) / lenSq).clamp(0.0, 1.0);
    final closest = GeoPoint(
      a.lat + t * (b.lat - a.lat),
      a.lng + t * (b.lng - a.lng),
    );
    final d = haversineMeters(point, closest);
    if (d < bestDistance) {
      bestDistance = d;
      bestIndex = i;
      bestPoint = closest;
    }
  }

  var traveled = 0.0;
  for (var i = 0; i < bestIndex; i++) {
    traveled += haversineMeters(route[i], route[i + 1]);
  }
  traveled += haversineMeters(route[bestIndex], bestPoint);

  return RouteProjection(
    snappedPoint: bestPoint,
    segmentIndex: bestIndex,
    distanceToRouteMeters: bestDistance,
    traveledMeters: traveled,
  );
}

/// Point located [meters] along [route] (clamped to 0..length) and the segment
/// it falls in.
({GeoPoint point, int segmentIndex}) pointAlongRoute(
  List<GeoPoint> route,
  double meters,
) {
  if (route.length < 2) {
    throw ArgumentError.value(route, 'route', 'needs at least 2 points');
  }
  if (meters <= 0) return (point: route.first, segmentIndex: 0);
  var remaining = meters;
  for (var i = 0; i < route.length - 1; i++) {
    final len = haversineMeters(route[i], route[i + 1]);
    if (remaining <= len) {
      final f = len == 0 ? 0.0 : remaining / len;
      final a = route[i];
      final b = route[i + 1];
      return (
        point: GeoPoint(
          a.lat + f * (b.lat - a.lat),
          a.lng + f * (b.lng - a.lng),
        ),
        segmentIndex: i,
      );
    }
    remaining -= len;
  }
  return (point: route.last, segmentIndex: route.length - 2);
}

/// Splits [route] at [snappedPoint], which lies on segment [segmentIndex].
/// traveled = route[0..segmentIndex] + snappedPoint;
/// remaining = snappedPoint + route[segmentIndex+1..].
({List<GeoPoint> traveled, List<GeoPoint> remaining}) splitRoute(
  List<GeoPoint> route,
  int segmentIndex,
  GeoPoint snappedPoint,
) {
  return (
    traveled: [...route.sublist(0, segmentIndex + 1), snappedPoint],
    remaining: [snappedPoint, ...route.sublist(segmentIndex + 1)],
  );
}
