import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rutta/core/domain/geo_point.dart';

part 'route_progress.freezed.dart';

@freezed
abstract class RouteProgress with _$RouteProgress {
  const factory RouteProgress({
    required GeoPoint snappedPoint,
    required int segmentIndex,
    required double traveledMeters,
    required double remainingMeters,
    required Duration eta,
    required bool isOffRoute,
    required double distanceToRouteMeters,
  }) = _RouteProgress;
}
