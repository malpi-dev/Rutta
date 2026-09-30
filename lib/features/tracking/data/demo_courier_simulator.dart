import 'dart:async';
import 'dart:math';

import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

/// Moves a fake courier along [route] (definition 8.3). Lives in data/ because
/// it is a mock implementation detail.
class DemoCourierSimulator {
  DemoCourierSimulator({
    required this.route,
    required this.clock,
    this.targetDuration = const Duration(seconds: 60),
    this.tick = const Duration(seconds: 1),
    this.startFraction = 0,

    /// 30 km/h, so the ETA looks realistic.
    this.reportedSpeedMps = 8.3,
    Random? random,
  }) : _random = random ?? Random(42);

  final List<GeoPoint> route;
  final Clock clock;
  final Duration targetDuration;
  final Duration tick;
  final double startFraction;
  final double reportedSpeedMps;
  final Random _random;

  /// Single-subscription stream. Emits the start point immediately, then one
  /// position per [tick], then exactly `route.last`, then closes. Cancelling
  /// the subscription stops the timer.
  Stream<DevicePosition> positions() {
    final total = routeLengthMeters(route);
    final baseSpeed = total / targetDuration.inSeconds;
    var meters = startFraction * total;
    Timer? timer;
    late final StreamController<DevicePosition> controller;

    DevicePosition position(GeoPoint point, double heading) => DevicePosition(
      point: point,
      timestamp: clock.nowUtc(),
      heading: heading,
      speedMps: reportedSpeedMps,
      accuracyMeters: 5,
    );

    DevicePosition at(double m) {
      final along = pointAlongRoute(route, m);
      final i = along.segmentIndex;
      return position(along.point, bearingDegrees(route[i], route[i + 1]));
    }

    void finish() {
      timer?.cancel();
      unawaited(controller.close());
    }

    controller = StreamController<DevicePosition>(
      onListen: () {
        controller.add(at(meters));
        timer = Timer.periodic(tick, (_) {
          meters +=
              baseSpeed * tick.inSeconds * (0.9 + 0.2 * _random.nextDouble());
          if (meters >= total) {
            controller.add(
              position(
                route.last,
                bearingDegrees(route[route.length - 2], route.last),
              ),
            );
            finish();
          } else {
            controller.add(at(meters));
          }
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }
}
