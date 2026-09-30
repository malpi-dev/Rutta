// Development script (never run by the app or CI).
//
// Fetches real driving routes for the CDMX demo places from the public OSRM
// server ONCE and generates:
//   - tool/routes/routes.json                      (committed cache)
//   - lib/features/orders/data/demo_routes.dart    (demo fixtures)
//   - the marked blocks of supabase/seed.sql and
//     supabase/scripts/create_sample_orders.sql    (if those files exist)
//
// Usage:
//   dart run tool/fetch_routes.dart               # calls OSRM
//   dart run tool/fetch_routes.dart --from-cache  # regenerates from routes.json
//
// Route geometry © OpenStreetMap contributors (ODbL), computed with OSRM.
import 'dart:convert';
import 'dart:io';

const _userAgent = 'rutta-dev-script (com.malpidev.rutta)';
const _cachePath = 'tool/routes/routes.json';
const _dartPath = 'lib/features/orders/data/demo_routes.dart';
const _sqlFiles = [
  'supabase/seed.sql',
  'supabase/scripts/create_sample_orders.sql',
];
const _beginMarker = '-- BEGIN GENERATED ROUTES (tool/fetch_routes.dart)';
const _endMarker = '-- END GENERATED ROUTES';

class _Place {
  const _Place(
    this.key,
    this.pickupName,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropoffAddress,
    this.dropoffLat,
    this.dropoffLng,
  );
  final String key;
  final String pickupName;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
}

const _places = <_Place>[
  _Place(
    'r1',
    'La Esquina Café',
    'Av. Álvaro Obregón 130, Roma Norte',
    19.41932,
    -99.16235,
    'Ámsterdam 240, Hipódromo Condesa',
    19.41070,
    -99.16960,
  ),
  _Place(
    'r2',
    'Farmacia Central',
    'Av. Cuauhtémoc 180, Roma Norte',
    19.42060,
    -99.15490,
    'Enrique Rébsamen 900, Narvarte Poniente',
    19.39330,
    -99.15710,
  ),
  _Place(
    'r3',
    'Green Bowl',
    'Av. Michoacán 78, Hipódromo Condesa',
    19.41150,
    -99.17290,
    'Río Lerma 150, Cuauhtémoc',
    19.42880,
    -99.16690,
  ),
  _Place(
    'r4',
    'Panadería San Miguel',
    'Colima 179, Roma Norte',
    19.41890,
    -99.15980,
    'Luz Saviñón 800, Narvarte Poniente',
    19.39400,
    -99.15300,
  ),
  _Place(
    'r5',
    'Farmacia Central',
    'Av. Cuauhtémoc 180, Roma Norte',
    19.42060,
    -99.15490,
    'Durango 280, Roma Norte',
    19.41940,
    -99.16880,
  ),
  _Place(
    'r6',
    'Green Bowl',
    'Av. Michoacán 78, Hipódromo Condesa',
    19.41150,
    -99.17290,
    'Liverpool 120, Juárez',
    19.42540,
    -99.16150,
  ),
];

Future<void> main(List<String> args) async {
  final fromCache = args.contains('--from-cache');
  final List<Map<String, dynamic>> routes;
  if (fromCache) {
    final data =
        jsonDecode(File(_cachePath).readAsStringSync()) as Map<String, dynamic>;
    routes = (data['routes'] as List).cast<Map<String, dynamic>>();
    stdout.writeln('Loaded ${routes.length} routes from $_cachePath');
  } else {
    routes = await _fetchAll();
    File(_cachePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({'routes': routes})}\n',
      );
    stdout.writeln('Wrote $_cachePath');
  }
  _writeDart(routes);
  for (final path in _sqlFiles) {
    _writeSql(path, routes);
  }
}

Future<List<Map<String, dynamic>>> _fetchAll() async {
  final client = HttpClient()..userAgent = _userAgent;
  final result = <Map<String, dynamic>>[];
  try {
    for (var i = 0; i < _places.length; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 1500));
      final p = _places[i];
      final route = await _fetchRoute(client, p);
      final distance = route['distanceMeters'] as int;
      if (distance < 1500 || distance > 4000) {
        stdout.writeln(
          'WARNING: ${p.key} is $distance m (expected 1500-4000). '
          'Adjust the destination coordinates and re-run.',
        );
      }
      stdout.writeln(
        '${p.key}: $distance m, '
        '${route['durationSeconds']} s, '
        '${(route['points'] as List).length} points',
      );
      result.add({
        'key': p.key,
        'pickupName': p.pickupName,
        'pickupAddress': p.pickupAddress,
        'pickupLat': p.pickupLat,
        'pickupLng': p.pickupLng,
        'dropoffAddress': p.dropoffAddress,
        'dropoffLat': p.dropoffLat,
        'dropoffLng': p.dropoffLng,
        ...route,
      });
    }
  } finally {
    client.close();
  }
  return result;
}

Future<Map<String, dynamic>> _fetchRoute(HttpClient client, _Place p) async {
  final url = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${p.pickupLng},${p.pickupLat};${p.dropoffLng},${p.dropoffLat}'
    '?overview=full&geometries=geojson',
  );
  Object? lastError;
  for (var attempt = 1; attempt <= 3; attempt++) {
    try {
      final request = await client.getUrl(url);
      request.headers.set('User-Agent', _userAgent);
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}: $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final route = (json['routes'] as List).first as Map<String, dynamic>;
      final coords = ((route['geometry'] as Map)['coordinates'] as List)
          .map((c) => [_round5((c as List)[0] as num), _round5(c[1] as num)])
          .toList(); // [lng, lat]
      return {
        'distanceMeters': (route['distance'] as num).round(),
        'durationSeconds': (route['duration'] as num).round(),
        'points': coords,
      };
    } on Object catch (e) {
      lastError = e;
      stdout.writeln('${p.key}: attempt $attempt failed ($e)');
      if (attempt < 3) await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
  stderr.writeln(
    'Could not fetch ${p.key} from OSRM after 3 attempts: $lastError\n'
    'Try again later (the public demo server may be busy).',
  );
  exit(1);
}

double _round5(num v) => (v * 100000).round() / 100000;

String _q(String s) => "'${s.replaceAll("'", "''")}'";

String _dartString(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

void _writeDart(List<Map<String, dynamic>> routes) {
  final b = StringBuffer()
    ..writeln('// GENERATED by tool/fetch_routes.dart. Do not edit by hand.')
    ..writeln(
      '// Route geometry © OpenStreetMap contributors (ODbL), '
      'computed with OSRM.',
    )
    ..writeln("import 'package:rutta/core/domain/geo_point.dart';")
    ..writeln("import 'package:rutta/features/orders/data/demo_route.dart';")
    ..writeln()
    ..writeln('const demoRoutes = <String, DemoRoute>{');
  for (final r in routes) {
    final pts = (r['points'] as List)
        .map((c) => 'GeoPoint(${(c as List)[1]}, ${c[0]})')
        .join(', ');
    b
      ..writeln("  '${r['key']}': DemoRoute(")
      ..writeln("    key: '${r['key']}',")
      ..writeln('    pickupName: ${_dartString(r['pickupName'] as String)},')
      ..writeln(
        '    pickupAddress: ${_dartString(r['pickupAddress'] as String)},',
      )
      ..writeln('    pickup: GeoPoint(${r['pickupLat']}, ${r['pickupLng']}),')
      ..writeln(
        '    dropoffAddress: ${_dartString(r['dropoffAddress'] as String)},',
      )
      ..writeln(
        '    dropoff: GeoPoint(${r['dropoffLat']}, ${r['dropoffLng']}),',
      )
      ..writeln('    points: [$pts],')
      ..writeln('    distanceMeters: ${r['distanceMeters']},')
      ..writeln('    durationSeconds: ${r['durationSeconds']},')
      ..writeln('  ),');
  }
  b.writeln('};');
  File(_dartPath).writeAsStringSync(b.toString());
  Process.runSync('dart', ['format', _dartPath]);
  stdout.writeln('Wrote $_dartPath');
}

String _sqlBlock(List<Map<String, dynamic>> routes) {
  final rows = routes
      .map((r) {
        final route = jsonEncode(r['points']);
        final key = _q(r['key'] as String);
        return '  ($key, ${_q(r['pickupName'] as String)}, '
            '${_q(r['pickupAddress'] as String)}, ${r['pickupLat']}, '
            '${r['pickupLng']},\n   ${_q(r['dropoffAddress'] as String)}, '
            "${r['dropoffLat']}, ${r['dropoffLng']}, '$route'::jsonb, "
            '${r['distanceMeters']}, ${r['durationSeconds']})';
      })
      .join(',\n');
  return '''
$_beginMarker
create temporary table seed_routes (
  key text primary key, pickup_name text, pickup_address text, pickup_lat double precision,
  pickup_lng double precision, dropoff_address text, dropoff_lat double precision, dropoff_lng double precision,
  route jsonb, distance_m integer, duration_s integer
);
insert into seed_routes values
$rows;
$_endMarker''';
}

void _writeSql(String path, List<Map<String, dynamic>> routes) {
  final file = File(path);
  if (!file.existsSync()) {
    stdout.writeln('Skipping $path (does not exist yet)');
    return;
  }
  final text = file.readAsStringSync();
  final start = text.indexOf(_beginMarker);
  final end = text.indexOf(_endMarker);
  if (start < 0 || end < start) {
    stdout.writeln('Skipping $path (markers not found)');
    return;
  }
  file.writeAsStringSync(
    text.replaceRange(start, end + _endMarker.length, _sqlBlock(routes)),
  );
  stdout.writeln('Updated $path');
}
