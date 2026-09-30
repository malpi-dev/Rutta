import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

class ShouldSendLocation {
  const ShouldSendLocation({
    this.minInterval = const Duration(seconds: 5),
    this.minDistanceMeters = 10,
    this.heartbeat = const Duration(seconds: 30),
    this.maxAccuracyMeters = 50,
  });

  final Duration minInterval;
  final double minDistanceMeters;
  final Duration heartbeat;
  final double maxAccuracyMeters;

  bool call({
    required DevicePosition candidate,
    required DateTime nowUtc,
    GeoPoint? lastSentPoint,
    DateTime? lastSentAt,
  }) {
    final accuracy = candidate.accuracyMeters;
    if (accuracy != null && accuracy > maxAccuracyMeters) return false;
    if (lastSentAt == null || lastSentPoint == null) return true;
    final elapsed = nowUtc.difference(lastSentAt);
    if (elapsed < minInterval) return false;
    if (elapsed >= heartbeat) return true;
    return haversineMeters(lastSentPoint, candidate.point) >= minDistanceMeters;
  }
}
