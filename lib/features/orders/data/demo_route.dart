import 'package:meta/meta.dart';
import 'package:rutta/core/domain/geo_point.dart';

/// A pickup/drop-off pair with its real (OSRM) route, used by demo fixtures.
@immutable
class DemoRoute {
  const DemoRoute({
    required this.key,
    required this.pickupName,
    required this.pickupAddress,
    required this.pickup,
    required this.dropoffAddress,
    required this.dropoff,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final String key;
  final String pickupName;
  final String pickupAddress;
  final GeoPoint pickup;
  final String dropoffAddress;
  final GeoPoint dropoff;
  final List<GeoPoint> points;
  final int distanceMeters;
  final int durationSeconds;
}
