import 'package:meta/meta.dart';

/// A WGS84 coordinate in degrees.
@immutable
class GeoPoint {
  const GeoPoint(this.lat, this.lng)
    : assert(lat >= -90 && lat <= 90, 'lat out of range'),
      assert(lng >= -180 && lng <= 180, 'lng out of range');

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}
