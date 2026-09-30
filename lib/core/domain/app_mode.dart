import 'package:meta/meta.dart';
import 'package:rutta/core/domain/user_role.dart';

/// Live = real repositories (Supabase). Demo = mock repositories with the
/// chosen role. Never persisted.
@immutable
sealed class AppMode {
  const AppMode();
}

@immutable
final class AppModeLive extends AppMode {
  const AppModeLive();

  @override
  bool operator ==(Object other) => other is AppModeLive;

  @override
  int get hashCode => (AppModeLive).hashCode;

  @override
  String toString() => 'AppModeLive()';
}

@immutable
final class AppModeDemo extends AppMode {
  const AppModeDemo(this.role);

  final UserRole role;

  @override
  bool operator ==(Object other) => other is AppModeDemo && other.role == role;

  @override
  int get hashCode => Object.hash(AppModeDemo, role);

  @override
  String toString() => 'AppModeDemo($role)';
}
