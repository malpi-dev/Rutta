import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/tracking/domain/should_send_location.dart';

import '../../../helpers/builders.dart';

void main() {
  const should = ShouldSendLocation();
  final t0 = DateTime.utc(2026, 9, 30, 12);
  const origin = GeoPoint(0, 0);

  // ~0.000009 degrees of longitude on the equator = 1 m.
  GeoPoint eastMeters(double m) => GeoPoint(0, m * 0.000008993);

  bool send(GeoPoint p, Duration after, {double? accuracy}) => should(
    candidate: buildPosition(p, t0.add(after), accuracy: accuracy),
    nowUtc: t0.add(after),
    lastSentPoint: origin,
    lastSentAt: t0,
  );

  test('first send is true', () {
    expect(
      should(candidate: buildPosition(origin, t0), nowUtc: t0),
      isTrue,
    );
  });

  test('too soon is false even when far', () {
    expect(send(eastMeters(50), const Duration(seconds: 3)), isFalse);
  });

  test('enough time but too close is false', () {
    expect(send(eastMeters(5), const Duration(seconds: 6)), isFalse);
  });

  test('enough time and distance is true', () {
    expect(send(eastMeters(12), const Duration(seconds: 6)), isTrue);
  });

  test('heartbeat without moving is true', () {
    expect(send(origin, const Duration(seconds: 31)), isTrue);
  });

  test('bad accuracy is discarded, even for the first send', () {
    expect(
      should(candidate: buildPosition(origin, t0, accuracy: 80), nowUtc: t0),
      isFalse,
    );
    expect(
      send(eastMeters(50), const Duration(seconds: 10), accuracy: 80),
      isFalse,
    );
  });

  test('null accuracy is accepted', () {
    expect(
      should(candidate: buildPosition(origin, t0), nowUtc: t0),
      isTrue,
    );
  });
}
