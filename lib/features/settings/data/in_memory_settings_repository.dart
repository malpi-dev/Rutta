import 'package:rutta/features/settings/domain/settings_repository.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this._theme = ThemePreference.system]);

  ThemePreference _theme;

  @override
  ThemePreference loadTheme() => _theme;

  @override
  Future<void> saveTheme(ThemePreference preference) async {
    _theme = preference;
  }
}
