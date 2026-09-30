import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/features/settings/data/prefs_settings_repository.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<PrefsSettingsRepository> repo(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    return PrefsSettingsRepository(await SharedPreferences.getInstance());
  }

  test('defaults to system', () async {
    expect((await repo({})).loadTheme(), ThemePreference.system);
  });

  test('round-trips every preference', () async {
    final r = await repo({});
    for (final p in ThemePreference.values) {
      await r.saveTheme(p);
      expect(r.loadTheme(), p);
    }
  });

  test('unknown stored value falls back to system', () async {
    expect(
      (await repo({'settings.theme': 'sepia'})).loadTheme(),
      ThemePreference.system,
    );
  });
}
