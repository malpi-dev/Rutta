import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';

part 'theme_controller.g.dart';

@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  @override
  ThemePreference build() => ref.watch(settingsRepositoryProvider).loadTheme();

  Future<void> change(ThemePreference preference) async {
    await ref.read(settingsRepositoryProvider).saveTheme(preference);
    state = preference;
  }
}
