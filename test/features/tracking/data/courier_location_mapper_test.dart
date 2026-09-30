import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/tracking/data/courier_location_mapper.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';

void main() {
  final row = {
    'courier_id': 'k1',
    'order_id': 'o1',
    'lat': 19.4,
    'lng': -99.1,
    'heading': 90,
    'speed_mps': 8.3,
    'accuracy_m': 5,
    'recorded_at': '2026-09-30T20:00:00+00:00',
  };

  test('row to entity', () {
    final l = courierLocationFromRow(row);
    expect(l.courierId, 'k1');
    expect(l.point, const GeoPoint(19.4, -99.1));
    expect(l.heading, 90);
    expect(l.accuracyMeters, 5);
    expect(l.recordedAt, DateTime.utc(2026, 9, 30, 20));
  });

  test('heading out of range becomes null (both directions)', () {
    expect(courierLocationFromRow({...row, 'heading': 400}).heading, isNull);
    final out = courierLocationToUpsertRow(
      CourierLocation(
        courierId: 'k1',
        orderId: 'o1',
        point: const GeoPoint(19.4, -99.1),
        recordedAt: DateTime.utc(2026),
        heading: 400,
      ),
    );
    expect(out['heading'], isNull);
  });

  test('entity to upsert row has no recorded_at', () {
    final out = courierLocationToUpsertRow(
      CourierLocation(
        courierId: 'k1',
        orderId: 'o1',
        point: const GeoPoint(19.4, -99.1),
        recordedAt: DateTime.utc(2026),
        heading: 10,
        speedMps: 8.3,
        accuracyMeters: 5,
      ),
    );
    expect(out, {
      'courier_id': 'k1',
      'order_id': 'o1',
      'lat': 19.4,
      'lng': -99.1,
      'heading': 10.0,
      'speed_mps': 8.3,
      'accuracy_m': 5.0,
    });
  });

  test('malformed row is an UnknownError', () {
    expect(
      () => courierLocationFromRow({'courier_id': 'k1'}),
      throwsA(isA<UnknownError>()),
    );
  });
}
