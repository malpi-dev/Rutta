import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/core/domain/geo_point.dart';

import '../../helpers/builders.dart';

void main() {
  group('GeoPoint', () {
    test('value equality and toString', () {
      expect(const GeoPoint(1, 2), const GeoPoint(1, 2));
      expect(const GeoPoint(1, 2).hashCode, const GeoPoint(1, 2).hashCode);
      expect(const GeoPoint(1, 2), isNot(const GeoPoint(1, 3)));
      expect(
        const GeoPoint(19.41932, -99.16235).toString(),
        'GeoPoint(19.41932, -99.16235)',
      );
    });
  });

  group('haversineMeters', () {
    test('0.01 degrees of longitude on the equator', () {
      expect(
        haversineMeters(const GeoPoint(0, 0), const GeoPoint(0, 0.01)),
        closeTo(1111.95, 0.5),
      );
    });

    test('same position is 0', () {
      expect(
        haversineMeters(
          const GeoPoint(19.4, -99.1),
          const GeoPoint(19.4, -99.1),
        ),
        0,
      );
    });
  });

  group('bearingDegrees', () {
    test('cardinal directions', () {
      const o = GeoPoint(0, 0);
      expect(bearingDegrees(o, const GeoPoint(0, 1)), closeTo(90, 0.001));
      expect(bearingDegrees(o, const GeoPoint(1, 0)), closeTo(0, 0.001));
      expect(bearingDegrees(o, const GeoPoint(0, -1)), closeTo(270, 0.001));
    });
  });

  group('routeLengthMeters', () {
    test('sums the segments', () {
      expect(routeLengthMeters(straightRoute), closeTo(2223.9, 1));
    });

    test('is 0 for fewer than 2 points', () {
      expect(routeLengthMeters(const []), 0);
      expect(routeLengthMeters(const [GeoPoint(0, 0)]), 0);
    });
  });

  group('projectOntoRoute', () {
    test('projects on the first segment', () {
      final p = projectOntoRoute(straightRoute, const GeoPoint(0.0001, 0.005));
      expect(p.segmentIndex, 0);
      expect(p.snappedPoint.lng, closeTo(0.005, 1e-9));
      expect(p.snappedPoint.lat, closeTo(0, 1e-9));
      expect(p.traveledMeters, closeTo(555.97, 0.5));
      expect(p.distanceToRouteMeters, closeTo(11.1, 0.2));
    });

    test('projects on the second segment', () {
      final p = projectOntoRoute(straightRoute, const GeoPoint(0.0001, 0.015));
      expect(p.segmentIndex, 1);
      expect(p.traveledMeters, closeTo(1667.9, 0.5));
    });

    test('clamps before the start and after the end', () {
      final before = projectOntoRoute(straightRoute, const GeoPoint(0, -0.001));
      expect(before.traveledMeters, 0);
      expect(before.snappedPoint, const GeoPoint(0, 0));
      final after = projectOntoRoute(straightRoute, const GeoPoint(0, 0.03));
      expect(after.traveledMeters, closeTo(2223.9, 1));
      expect(after.segmentIndex, 1);
    });

    test('ties go to the lowest segment index', () {
      final p = projectOntoRoute(straightRoute, const GeoPoint(0, 0.01));
      expect(p.segmentIndex, 0);
    });

    test('a zero-length segment does not break', () {
      final p = projectOntoRoute(
        const [GeoPoint(0, 0), GeoPoint(0, 0)],
        const GeoPoint(0, 0.001),
      );
      expect(p.traveledMeters, 0);
    });

    test('throws ArgumentError with fewer than 2 points', () {
      expect(
        () => projectOntoRoute(const [GeoPoint(0, 0)], const GeoPoint(0, 0)),
        throwsArgumentError,
      );
    });
  });

  group('pointAlongRoute', () {
    test('0 is the start', () {
      final r = pointAlongRoute(straightRoute, 0);
      expect(r.point, straightRoute.first);
      expect(r.segmentIndex, 0);
    });

    test('inside the first segment', () {
      final r = pointAlongRoute(straightRoute, 555.97);
      expect(r.point.lng, closeTo(0.005, 1e-5));
      expect(r.segmentIndex, 0);
    });

    test('inside the second segment', () {
      final r = pointAlongRoute(straightRoute, 1667.9);
      expect(r.point.lng, closeTo(0.015, 1e-5));
      expect(r.segmentIndex, 1);
    });

    test('clamps negative and too large values', () {
      expect(pointAlongRoute(straightRoute, -5).point, straightRoute.first);
      final end = pointAlongRoute(straightRoute, 99999);
      expect(end.point, straightRoute.last);
      expect(end.segmentIndex, 1);
    });
  });

  group('splitRoute', () {
    test('splits at the snapped point', () {
      final r = splitRoute(straightRoute, 0, const GeoPoint(0, 0.005));
      expect(r.traveled, const [GeoPoint(0, 0), GeoPoint(0, 0.005)]);
      expect(r.remaining, const [
        GeoPoint(0, 0.005),
        GeoPoint(0, 0.01),
        GeoPoint(0, 0.02),
      ]);
    });
  });
}
