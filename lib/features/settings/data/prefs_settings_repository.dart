import 'package:rutta/features/settings/domain/settings_repository.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'settings.theme';

  @override
  ThemePreference loadTheme() {
    final name = _prefs.getString(_themeKey);
    return ThemePreference.values.firstWhere(
      (p) => p.name == name,
      orElse: () => ThemePreference.system,
    );
  }

  @override
  Future<void> saveTheme(ThemePreference preference) async {
    await _prefs.setString(_themeKey, preference.name);
  }
}
