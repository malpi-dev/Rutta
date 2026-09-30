import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/features/orders/data/demo_routes.dart';

void main() {
  test('has the six CDMX routes r1..r6', () {
    expect(demoRoutes.keys, ['r1', 'r2', 'r3', 'r4', 'r5', 'r6']);
  });

  for (final entry in demoRoutes.entries) {
    test('${entry.key} is a coherent route', () {
      final r = entry.value;
      expect(r.key, entry.key);
      expect(r.points.length, greaterThanOrEqualTo(2));
      expect(haversineMeters(r.points.first, r.pickup), lessThan(150));
      expect(haversineMeters(r.points.last, r.dropoff), lessThan(150));
      expect(r.distanceMeters, inInclusiveRange(1000, 5000));
      expect(
        routeLengthMeters(r.points),
        closeTo(r.distanceMeters, r.distanceMeters * 0.15),
      );
      expect(r.durationSeconds, greaterThan(0));
    });
  }
}
