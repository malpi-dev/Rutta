/// Build-time configuration (`--dart-define-from-file=.env.json`).
/// Never throws: without `.env.json` the app runs in demo-only mode.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const mapUserAgentPackage = String.fromEnvironment(
    'MAP_USER_AGENT_PACKAGE',
    defaultValue: 'com.malpidev.rutta',
  );
  static const _minIntervalS = String.fromEnvironment(
    'LOCATION_MIN_INTERVAL_S',
    defaultValue: '5',
  );
  static const _minDistanceM = String.fromEnvironment(
    'LOCATION_MIN_DISTANCE_M',
    defaultValue: '10',
  );

  /// Development only: the demo courier uses the real device GPS
  /// (`--dart-define=DEMO_REAL_GPS=true`) to try permissions and throttling.
  static const demoUsesRealGps = bool.fromEnvironment('DEMO_REAL_GPS');

  /// Without both values the app runs in demo-only mode.
  static bool get isBackendConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static Duration get locationMinInterval =>
      Duration(seconds: int.tryParse(_minIntervalS) ?? 5);

  static double get locationMinDistanceMeters =>
      double.tryParse(_minDistanceM) ?? 10;
}
