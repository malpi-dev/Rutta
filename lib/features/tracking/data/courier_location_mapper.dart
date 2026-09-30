import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';

CourierLocation courierLocationFromRow(Map<String, dynamic> row) {
  try {
    final heading = (row['heading'] as num?)?.toDouble();
    return CourierLocation(
      courierId: row['courier_id'] as String,
      orderId: row['order_id'] as String,
      point: GeoPoint(
        (row['lat'] as num).toDouble(),
        (row['lng'] as num).toDouble(),
      ),
      recordedAt: DateTime.parse(row['recorded_at'] as String).toUtc(),
      heading: heading != null && heading >= 0 && heading <= 360
          ? heading
          : null,
      speedMps: (row['speed_mps'] as num?)?.toDouble(),
      accuracyMeters: (row['accuracy_m'] as num?)?.toDouble(),
    );
  } on Object catch (error) {
    throw UnknownError(error);
  }
}

/// Upsert payload. `recorded_at` is omitted: a trigger sets it with the
/// server clock.
Map<String, dynamic> courierLocationToUpsertRow(CourierLocation l) {
  final heading = l.heading;
  return {
    'courier_id': l.courierId,
    'order_id': l.orderId,
    'lat': l.point.lat,
    'lng': l.point.lng,
    'heading': heading != null && heading >= 0 && heading <= 360
        ? heading
        : null,
    'speed_mps': l.speedMps,
    'accuracy_m': l.accuracyMeters,
  };
}
