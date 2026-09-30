import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/domain/user_role.dart';

part 'app_mode_provider.g.dart';

@Riverpod(keepAlive: true)
class AppModeController extends _$AppModeController {
  /// Never persisted.
  @override
  AppMode build() => const AppModeLive();

  void enterDemo(UserRole role) => state = AppModeDemo(role);

  void exitDemo() => state = const AppModeLive();
}
