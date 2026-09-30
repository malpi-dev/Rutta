import 'package:rutta/features/settings/domain/theme_preference.dart';

// Port interface; will grow with more settings.
abstract interface class SettingsRepository {
  /// Synchronous: needed before the first frame.
  ThemePreference loadTheme();

  Future<void> saveTheme(ThemePreference preference);
}
