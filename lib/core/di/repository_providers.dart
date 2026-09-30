import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/features/settings/data/prefs_settings_repository.dart';
import 'package:rutta/features/settings/domain/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'repository_providers.g.dart';

/// Composition root: the only file (besides `main.dart`) that wires `data/`
/// implementations of several features.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError(
  'sharedPreferencesProvider must be overridden in main()',
);

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    PrefsSettingsRepository(ref.watch(sharedPreferencesProvider));
