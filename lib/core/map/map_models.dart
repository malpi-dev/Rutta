import 'package:flutter/material.dart';
import 'package:rutta/core/domain/geo_point.dart';

/// A widget pinned to a geographic point.
@immutable
class MapMarker {
  const MapMarker({
    required this.id,
    required this.point,
    required this.child,
    this.width = 44,
    this.height = 44,
    this.alignment = Alignment.center,
  });

  /// Stable id ('pickup', 'dropoff', 'courier').
  final String id;
  final GeoPoint point;

  /// Already rotated/styled by the caller.
  final Widget child;
  final double width;
  final double height;

  /// Pins use [Alignment.topCenter] so the tip touches the point.
  final Alignment alignment;
}

/// A line drawn over the map.
@immutable
class MapPolyline {
  const MapPolyline({
    required this.id,
    required this.points,
    required this.color,
    this.width = 6,
    this.dotted = false,
  });

  final String id;
  final List<GeoPoint> points;
  final Color color;
  final double width;
  final bool dotted;
}
