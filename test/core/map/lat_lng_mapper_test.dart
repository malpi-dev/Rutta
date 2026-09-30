import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/map/flutter_map/lat_lng_mapper.dart';

void main() {
  test('GeoPoint <-> LatLng round trip is lossless', () {
    const p = GeoPoint(19.41932, -99.16235);
    final ll = toLatLng(p);
    expect(ll, const LatLng(19.41932, -99.16235));
    expect(toGeoPoint(ll), p);
  });
}
