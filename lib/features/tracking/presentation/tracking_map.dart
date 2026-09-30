import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/config/env.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/map/map_models.dart';
import 'package:rutta/core/map/rutta_map.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/theme/rutta_colors.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/presentation/tracking_providers.dart';
import 'package:rutta/features/tracking/presentation/widgets/map_pins.dart';

/// Map of an order: pins, traveled/remaining route and the courier marker,
/// which glides along the route between location updates.
class TrackingMap extends ConsumerStatefulWidget {
  const TrackingMap({
    required this.order,
    required this.role,
    required this.controller,
    super.key,
  });

  final Order order;
  final UserRole role;
  final RuttaMapController controller;

  @override
  ConsumerState<TrackingMap> createState() => _TrackingMapState();
}

class _Displayed {
  const _Displayed(
    this.point,
    this.heading,
    this.segmentIndex,
    this.splitPoint,
  );

  final GeoPoint point;
  final double heading;

  /// Route segment that contains [splitPoint].
  final int segmentIndex;

  /// Where the route is split into traveled/remaining (the marker itself, or
  /// its projection on the route while the courier is off route).
  final GeoPoint splitPoint;
}

class _TrackingMapState extends ConsumerState<TrackingMap>
    with SingleTickerProviderStateMixin {
  /// Offsets larger than this backwards along the route are not animated.
  static const _backwardsJumpMeters = 30.0;
  static const _minAnimation = Duration(milliseconds: 500);
  static const _maxAnimation = Duration(seconds: 6);

  late final AnimationController _animation;
  ProviderSubscription<AsyncValue<CourierLocation?>>? _subscription;

  CourierLocation? _location;
  DateTime? _lastRecordedAt;
  var _fromMeters = 0.0;
  var _toMeters = 0.0;
  var _fromPoint = const GeoPoint(0, 0);
  var _toPoint = const GeoPoint(0, 0);
  var _fromOnRoute = true;
  var _toOnRoute = true;
  var _toSegment = 0;
  var _toSnapped = const GeoPoint(0, 0);

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: Env.locationMinInterval,
    );
    _syncSubscription();
  }

  @override
  void didUpdateWidget(TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) _closeSubscription();
    _syncSubscription();
  }

  @override
  void dispose() {
    _subscription?.close();
    _animation.dispose();
    super.dispose();
  }

  void _closeSubscription() {
    _subscription?.close();
    _subscription = null;
    _location = null;
    _lastRecordedAt = null;
    _animation.stop();
  }

  /// The location is only observed while the order is in progress, so
  /// created/assigned/finished orders never start a subscription.
  void _syncSubscription() {
    final inProgress = widget.order.status.isInProgress;
    if (inProgress && _subscription == null) {
      _subscription = ref.listenManual(
        courierLocationProvider(widget.order.id),
        (_, next) => _onLocation(next.value),
        fireImmediately: true,
      );
    } else if (!inProgress && _subscription != null) {
      _closeSubscription();
    }
  }

  void _onLocation(CourierLocation? location) {
    if (location == null) {
      _location = null;
      _lastRecordedAt = null;
      if (mounted) setState(() {});
      return;
    }
    final order = widget.order;
    final progress = ref.read(computeRouteProgressProvider)(
      route: order.route,
      position: location.point,
      speedMps: location.speedMps,
    );
    final onRoute = !progress.isOffRoute;
    final previous = _lastRecordedAt;
    final wasPlaced = _location != null && previous != null;

    // Where the marker is right now (start of the next animation).
    final current = wasPlaced ? _displayed() : null;
    final currentMeters = wasPlaced && _fromOnRoute && _toOnRoute
        ? _lerp(_fromMeters, _toMeters, _animation.value)
        : null;

    _location = location;
    _lastRecordedAt = location.recordedAt;
    _toOnRoute = onRoute;
    _toPoint = onRoute ? progress.snappedPoint : location.point;
    _toMeters = progress.traveledMeters;
    _toSegment = progress.segmentIndex;
    _toSnapped = progress.snappedPoint;

    final goesBackwards =
        currentMeters != null &&
        onRoute &&
        _toMeters < currentMeters - _backwardsJumpMeters;
    if (current == null || goesBackwards) {
      _fromPoint = _toPoint;
      _fromMeters = _toMeters;
      _fromOnRoute = _toOnRoute;
      _animation.value = 1;
    } else {
      _fromPoint = current.point;
      _fromOnRoute = onRoute && (currentMeters != null);
      _fromMeters = currentMeters ?? _toMeters;
      final gap = location.recordedAt.difference(previous!);
      _animation.duration = _clampDuration(gap);
      unawaited(_animation.forward(from: 0));
    }
    if (mounted) setState(() {});
  }

  Duration _clampDuration(Duration gap) {
    if (gap < _minAnimation) return _minAnimation;
    if (gap > _maxAnimation) return _maxAnimation;
    return gap;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Marker position for the current animation frame.
  _Displayed _displayed() {
    final route = widget.order.route;
    final t = _animation.value;
    if (_fromOnRoute && _toOnRoute) {
      final meters = _lerp(_fromMeters, _toMeters, t);
      final along = pointAlongRoute(route, meters);
      final segment = math.min(along.segmentIndex, route.length - 2);
      return _Displayed(
        along.point,
        bearingDegrees(route[segment], route[segment + 1]),
        segment,
        along.point,
      );
    }
    final point = GeoPoint(
      _lerp(_fromPoint.lat, _toPoint.lat, t),
      _lerp(_fromPoint.lng, _toPoint.lng, t),
    );
    final heading =
        _location?.heading ??
        (_fromPoint == _toPoint ? 0.0 : bearingDegrees(_fromPoint, _toPoint));
    return _Displayed(point, heading, _toSegment, _toSnapped);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final colors = context.colors;
    final l10n = context.l10n;
    final stale = ref.watch(isCourierLocationStaleProvider(order.id));
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final showCourier =
                  order.status.isInProgress && _location != null;
              final displayed = showCourier ? _displayed() : null;
              return RuttaMap(
                props: RuttaMapProps(
                  initialFit: order.route,
                  controller: widget.controller,
                  darkMode: Theme.of(context).brightness == Brightness.dark,
                  polylines: _polylines(order, displayed, colors),
                  markers: [
                    MapMarker(
                      id: 'pickup',
                      point: order.pickup.point,
                      alignment: Alignment.topCenter,
                      child: const PickupPin(),
                    ),
                    MapMarker(
                      id: 'dropoff',
                      point: order.dropoff.point,
                      alignment: Alignment.topCenter,
                      child: const DropoffPin(),
                    ),
                    if (displayed != null)
                      MapMarker(
                        id: 'courier',
                        point: displayed.point,
                        width: 36,
                        height: 36,
                        child: Semantics(
                          label: l10n.courierPinLabel,
                          value:
                              '${displayed.point.lat.toStringAsFixed(5)},'
                              '${displayed.point.lng.toStringAsFixed(5)}',
                          child: CourierPin(
                            headingDegrees: displayed.heading,
                            stale: stale,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (order.status.isInProgress && _location != null)
          Positioned(
            top: 48,
            right: 12,
            child: Semantics(
              identifier: 'tracking-recenter',
              child: FloatingActionButton.small(
                key: const Key('tracking-recenter'),
                heroTag: null,
                tooltip: l10n.recenterOnCourier,
                onPressed: () =>
                    widget.controller.centerOn(_displayed().point, zoom: 16),
                child: const Icon(Icons.my_location),
              ),
            ),
          ),
      ],
    );
  }

  List<MapPolyline> _polylines(
    Order order,
    _Displayed? displayed,
    RuttaColors colors,
  ) {
    if (displayed == null) {
      return [
        MapPolyline(
          id: 'route',
          points: order.route,
          color: colors.routeRemaining,
        ),
      ];
    }
    final split = splitRoute(
      order.route,
      displayed.segmentIndex,
      displayed.splitPoint,
    );
    return [
      MapPolyline(
        id: 'traveled',
        points: split.traveled,
        color: colors.routeTraveled,
      ),
      MapPolyline(
        id: 'remaining',
        points: split.remaining,
        color: colors.routeRemaining,
      ),
    ];
  }
}
