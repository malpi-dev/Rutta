// Development script (never run by the app or CI).
//
// Drives the Android emulator's GPS along one of the demo routes, so the
// courier's location sharing can be tried with a single emulator.
//
// Usage:
//   dart run tool/emulator_drive.dart r2 --interval 2
//   dart run tool/emulator_drive.dart r2 --serial emulator-5556
//
// Works with `flutter run --dart-define=DEMO_REAL_GPS=true` (phase 08) and
// with the real backend (phase 11). Note: `adb emu geo fix` takes longitude
// first.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _routesPath = 'tool/routes/routes.json';
const _minSpacingMeters = 20.0;

Future<void> main(List<String> args) async {
  String? key;
  String? serial;
  var interval = 2;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--interval':
        interval = int.tryParse(i + 1 < args.length ? args[++i] : '') ?? 0;
      case '--serial':
        serial = i + 1 < args.length ? args[++i] : null;
      default:
        key = args[i];
    }
  }
  if (key == null || interval < 1) {
    stdout.writeln(
      'Usage: dart run tool/emulator_drive.dart <route-key> '
      '[--interval <seconds>] [--serial <adb-serial>]',
    );
    exit(64);
  }

  final file = File(_routesPath);
  if (!file.existsSync()) {
    stdout.writeln('Missing $_routesPath. Run tool/fetch_routes.dart first.');
    exit(1);
  }
  final routes =
      (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['routes']
          as List<dynamic>;
  final route = routes.cast<Map<String, dynamic>>().where(
    (r) => r['key'] == key,
  );
  if (route.isEmpty) {
    final keys = routes.map((r) => (r as Map<String, dynamic>)['key']);
    stdout.writeln('Unknown route "$key". Available: ${keys.join(', ')}');
    exit(1);
  }

  // Points are [lng, lat] (GeoJSON order).
  final all = (route.first['points'] as List<dynamic>)
      .map((p) => (p as List<dynamic>).cast<num>())
      .map((p) => (lng: p[0].toDouble(), lat: p[1].toDouble()))
      .toList();
  final points = [all.first];
  for (final p in all.skip(1)) {
    if (_meters(points.last, p) >= _minSpacingMeters) points.add(p);
  }
  if (points.last != all.last) points.add(all.last);

  final adb = <String>[
    if (serial != null) ...['-s', serial],
  ];
  if (!await _hasEmulator(serial)) {
    stdout.writeln(
      'No emulator found. Is `adb` on the PATH and an emulator running?',
    );
    exit(1);
  }

  stdout.writeln(
    'Driving route $key: ${points.length} points, every ${interval}s '
    '(Ctrl+C to stop).',
  );
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    final result = await Process.run('adb', [
      ...adb,
      'emu',
      'geo',
      'fix',
      '${p.lng}',
      '${p.lat}',
    ]);
    if (result.exitCode != 0) {
      stdout.writeln('adb failed: ${result.stderr}');
      exit(1);
    }
    stdout.writeln('[${i + 1}/${points.length}] ${p.lat}, ${p.lng}');
    if (i < points.length - 1) {
      await Future<void>.delayed(Duration(seconds: interval));
    }
  }
  stdout.writeln('Arrived.');
}

Future<bool> _hasEmulator(String? serial) async {
  try {
    final result = await Process.run('adb', ['devices']);
    if (result.exitCode != 0) return false;
    final devices = (result.stdout as String)
        .split('\n')
        .skip(1)
        .map((l) => l.trim().split(RegExp(r'\s+')))
        .where((f) => f.length >= 2 && f[1] == 'device')
        .map((f) => f[0])
        .toList();
    return serial == null
        ? devices.any((d) => d.startsWith('emulator-'))
        : devices.contains(serial);
  } on ProcessException {
    return false;
  }
}

double _meters(({double lat, double lng}) a, ({double lat, double lng}) b) {
  const earth = 6371008.8;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earth * math.asin(math.sqrt(h));
}
