import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/map/map_models.dart';
import 'package:rutta/core/map/rutta_map_provider.dart';

/// What a concrete map implementation must offer to the controller.
abstract interface class RuttaMapDelegate {
  void fitPoints(List<GeoPoint> points, {EdgeInsets padding});
  void centerOn(GeoPoint point, {double? zoom});
}

/// Created by screens before the map exists; the implementation attaches
/// itself when built. Calls made while detached are ignored.
class RuttaMapController {
  RuttaMapDelegate? _delegate;

  // ignore: use_setters_to_change_properties, paired with detach().
  void attach(RuttaMapDelegate delegate) => _delegate = delegate;

  void detach(RuttaMapDelegate delegate) {
    if (identical(_delegate, delegate)) _delegate = null;
  }

  bool get isAttached => _delegate != null;

  void fitPoints(
    List<GeoPoint> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) => _delegate?.fitPoints(points, padding: padding);

  void centerOn(GeoPoint point, {double? zoom}) =>
      _delegate?.centerOn(point, zoom: zoom);
}

@immutable
class RuttaMapProps {
  const RuttaMapProps({
    required this.initialFit,
    this.markers = const [],
    this.polylines = const [],
    this.controller,
    this.darkMode = false,
    this.padding = const EdgeInsets.all(48),
  });

  /// Points the camera frames on first build (at least one).
  final List<GeoPoint> initialFit;
  final List<MapMarker> markers;
  final List<MapPolyline> polylines;
  final RuttaMapController? controller;
  final bool darkMode;
  final EdgeInsets padding;
}

typedef RuttaMapBuilder = Widget Function(RuttaMapProps props);

/// The only map widget screens use. The concrete implementation comes from
/// `ruttaMapBuilderProvider`, so switching to Google Maps = a new builder +
/// changing that provider. Tests override it with a fake.
class RuttaMap extends ConsumerWidget {
  const RuttaMap({required this.props, super.key});

  final RuttaMapProps props;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(ruttaMapBuilderProvider)(props);
}
