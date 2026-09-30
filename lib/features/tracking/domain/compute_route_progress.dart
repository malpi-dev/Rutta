import 'dart:math' as math;

import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/tracking/domain/route_progress.dart';

class ComputeRouteProgress {
  const ComputeRouteProgress({
    this.offRouteThresholdMeters = 75,
    this.fallbackSpeedMps = 25 / 3.6,
  });

  final double offRouteThresholdMeters;

  /// 25 km/h by default.
  final double fallbackSpeedMps;

  RouteProgress call({
    required List<GeoPoint> route,
    required GeoPoint position,
    double? speedMps,
  }) {
    final projection = projectOntoRoute(route, position);
    final total = routeLengthMeters(route);
    final remaining = math.max(0, total - projection.traveledMeters);
    final reliable = speedMps != null && speedMps >= 1.5 && speedMps <= 45;
    final speed = reliable ? speedMps : fallbackSpeedMps;
    return RouteProgress(
      snappedPoint: projection.snappedPoint,
      segmentIndex: projection.segmentIndex,
      traveledMeters: projection.traveledMeters,
      remainingMeters: remaining.toDouble(),
      eta: Duration(seconds: (remaining / speed).round()),
      isOffRoute: projection.distanceToRouteMeters > offRouteThresholdMeters,
      distanceToRouteMeters: projection.distanceToRouteMeters,
    );
  }
}
