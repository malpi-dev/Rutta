import 'package:latlong2/latlong.dart';
import 'package:rutta/core/domain/geo_point.dart';

LatLng toLatLng(GeoPoint p) => LatLng(p.lat, p.lng);

GeoPoint toGeoPoint(LatLng p) => GeoPoint(p.latitude, p.longitude);
