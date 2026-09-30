import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rutta/core/domain/geo_point.dart';

part 'courier_location.freezed.dart';

@freezed
abstract class CourierLocation with _$CourierLocation {
  const factory CourierLocation({
    required String courierId,
    required String orderId,
    required GeoPoint point,

    /// UTC. The server overwrites it with its own time on insert/update.
    required DateTime recordedAt,

    /// 0..360.
    double? heading,
    double? speedMps,
    double? accuracyMeters,
  }) = _CourierLocation;

  const CourierLocation._();

  /// Definition 6.3 rule 7: older than 30 s = stale (shown as such, never
  /// hidden).
  bool isStale(
    DateTime nowUtc, {
    Duration threshold = const Duration(seconds: 30),
  }) => nowUtc.difference(recordedAt) > threshold;
}
