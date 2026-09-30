import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';

void main() {
  final recorded = DateTime.utc(2026, 9, 30, 12);
  final location = CourierLocation(
    courierId: 'k1',
    orderId: 'o1',
    point: const GeoPoint(0, 0),
    recordedAt: recorded,
  );

  test('exactly 30 s is not stale', () {
    expect(
      location.isStale(recorded.add(const Duration(seconds: 30))),
      isFalse,
    );
  });

  test('31 s is stale', () {
    expect(location.isStale(recorded.add(const Duration(seconds: 31))), isTrue);
  });
}
