import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/router/routes.dart';
import 'package:rutta/features/auth/domain/session_state.dart';

/// Pure redirect logic (testable without widgets). Returns null to stay.
String? appRedirect({
  required String location,
  required AppMode mode,
  required AsyncValue<SessionState> session,
}) {
  // Debug-only route (only registered when kDebugMode): never redirect it.
  if (location == Routes.devMap) return null;

  const entry = {
    Routes.startup,
    Routes.login,
    Routes.verify,
    Routes.onboarding,
  };

  String? forRole(UserRole role) {
    final home = Routes.homeFor(role);
    final otherPrefix = role == UserRole.customer ? '/courier' : '/customer';
    if (entry.contains(location) || location.startsWith(otherPrefix)) {
      return home;
    }
    return null; // own routes and /settings are allowed
  }

  if (mode case AppModeDemo(:final role)) return forRole(role);

  final current = session.hasValue ? session.value : null;
  if (current == null) {
    // Loading or error.
    return location == Routes.startup ? null : Routes.startup;
  }
  return switch (current) {
    SessionSignedOut() =>
      (location == Routes.login || location == Routes.verify)
          ? null
          : Routes.login,
    SessionNeedsProfile() =>
      location == Routes.onboarding ? null : Routes.onboarding,
    SessionSignedIn(:final profile) => forRole(profile.role),
  };
}
