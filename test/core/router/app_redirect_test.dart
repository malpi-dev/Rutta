import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/router/app_redirect.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';

void main() {
  const live = AppModeLive();
  const loading = AsyncValue<SessionState>.loading();
  final error = AsyncValue<SessionState>.error(
    StateError('x'),
    StackTrace.empty,
  );
  const signedOut = AsyncValue<SessionState>.data(SessionSignedOut());
  const needsProfile = AsyncValue<SessionState>.data(
    SessionNeedsProfile('a@b.c'),
  );
  AsyncValue<SessionState> signedIn(UserRole role) => AsyncValue.data(
    SessionSignedIn(
      UserProfile(id: 'u1', fullName: 'Test', role: role),
      'a@b.c',
    ),
  );

  final cases = <(String, AppMode, AsyncValue<SessionState>, String, String?)>[
    ('live loading', live, loading, '/customer/orders', '/'),
    ('live loading', live, loading, '/', null),
    ('live error', live, error, '/login', '/'),
    ('live signedOut', live, signedOut, '/', '/login'),
    ('live signedOut', live, signedOut, '/verify', null),
    ('live signedOut', live, signedOut, '/customer/orders', '/login'),
    ('live needsProfile', live, needsProfile, '/login', '/onboarding'),
    ('live needsProfile', live, needsProfile, '/onboarding', null),
    (
      'live customer',
      live,
      signedIn(UserRole.customer),
      '/login',
      '/customer/orders',
    ),
    (
      'live customer',
      live,
      signedIn(UserRole.customer),
      '/courier/orders/abc',
      '/customer/orders',
    ),
    (
      'live customer',
      live,
      signedIn(UserRole.customer),
      '/customer/orders/abc',
      null,
    ),
    (
      'live courier',
      live,
      signedIn(UserRole.courier),
      '/onboarding',
      '/courier/orders',
    ),
    ('live courier', live, signedIn(UserRole.courier), '/settings', null),
    (
      'demo customer',
      const AppModeDemo(UserRole.customer),
      signedOut,
      '/login',
      '/customer/orders',
    ),
    (
      'demo courier',
      const AppModeDemo(UserRole.courier),
      signedOut,
      '/customer/orders',
      '/courier/orders',
    ),
    (
      'demo courier',
      const AppModeDemo(UserRole.courier),
      loading,
      '/courier/orders/x',
      null,
    ),
  ];

  for (final (name, mode, session, location, expected) in cases) {
    test('$name at $location -> ${expected ?? 'stay'}', () {
      expect(
        appRedirect(location: location, mode: mode, session: session),
        expected,
      );
    });
  }
}
