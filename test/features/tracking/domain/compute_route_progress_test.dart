import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/tracking/domain/compute_route_progress.dart';

import '../../../helpers/builders.dart';

void main() {
  const compute = ComputeRouteProgress();

  test('on the first segment', () {
    final p = compute(
      route: straightRoute,
      position: const GeoPoint(0.0001, 0.005),
    );
    expect(p.segmentIndex, 0);
    expect(p.traveledMeters, closeTo(555.97, 0.5));
    expect(p.remainingMeters, closeTo(1667.9, 0.5));
    expect(p.distanceToRouteMeters, closeTo(11.1, 0.2));
    expect(p.isOffRoute, isFalse);
  });

  test('on the second segment', () {
    final p = compute(
      route: straightRoute,
      position: const GeoPoint(0.0001, 0.015),
    );
    expect(p.segmentIndex, 1);
    expect(p.traveledMeters, closeTo(1667.9, 0.5));
  });

  test('before the start', () {
    final p = compute(
      route: straightRoute,
      position: const GeoPoint(0, -0.001),
    );
    expect(p.traveledMeters, 0);
  });

  test('after the end: nothing remaining and off route', () {
    final p = compute(route: straightRoute, position: const GeoPoint(0, 0.03));
    expect(p.remainingMeters, closeTo(0, 0.5));
    expect(p.isOffRoute, isTrue);
  });

  test('far from the route is off route', () {
    final p = compute(
      route: straightRoute,
      position: const GeoPoint(0.001, 0.005),
    );
    expect(p.distanceToRouteMeters, closeTo(111.2, 0.5));
    expect(p.isOffRoute, isTrue);
  });

  group('ETA', () {
    const position = GeoPoint(0, 0.005);

    test('falls back to 25 km/h without speed', () {
      final p = compute(route: straightRoute, position: position);
      expect(p.eta, const Duration(seconds: 240));
    });

    test('uses a reliable speed', () {
      final p = compute(route: straightRoute, position: position, speedMps: 10);
      expect(p.eta, const Duration(seconds: 167));
    });

    test('ignores an unreliable speed', () {
      final p = compute(
        route: straightRoute,
        position: position,
        speedMps: 0.5,
      );
      expect(p.eta, const Duration(seconds: 240));
    });
  });

  test('works with a 2-point route', () {
    final p = compute(
      route: const [GeoPoint(0, 0), GeoPoint(0, 0.01)],
      position: const GeoPoint(0, 0.005),
    );
    expect(p.segmentIndex, 0);
    expect(p.remainingMeters, closeTo(556, 1));
  });
}
