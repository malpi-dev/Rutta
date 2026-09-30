import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/auth/data/mock_auth_repository.dart';
import 'package:rutta/features/auth/domain/demo_otp.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';
import 'package:rutta/features/settings/data/in_memory_settings_repository.dart';

import '../../../helpers/demo.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/test_overrides.dart';
import 'auth_test_helpers.dart';

void main() {
  Future<void> pumpRutta(
    WidgetTester tester,
    MockAuthRepository repo, {
    List<Override> extra = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          // screenOverrides already carries the clock and the fake map.
          if (extra.isEmpty)
            ...testOverrides()
          else
            settingsRepositoryProvider.overrideWithValue(
              InMemorySettingsRepository(),
            ),
          ...authOverrides(repo),
          ...extra,
        ],
        child: const RuttaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester, String email) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('verify-code')), demoOtpCode);
    await tester.pumpAndSettle();
  }

  testWidgets('new customer: login, verify, onboarding, home, sign out', (
    tester,
  ) async {
    await pumpRutta(tester, MockAuthRepository());
    expect(find.byKey(const Key('login-email')), findsOneWidget);

    await login(tester, 'ana@rutta.test');
    expect(find.byKey(const Key('onboarding-name')), findsOneWidget);

    // Empty name -> inline validation error.
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Ana');
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('My orders'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sign-out-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('existing courier goes straight to /courier/orders', (
    tester,
  ) async {
    const courier = UserProfile(
      id: 'c1',
      fullName: 'Carlos',
      role: UserRole.courier,
    );
    await pumpRutta(
      tester,
      MockAuthRepository(
        existingProfile: courier,
        existingProfileEmail: 'courier1@rutta.test',
      ),
      // Live repositories arrive in phase 11: the courier home needs mocks.
      extra: screenOverrides(testDemoStore(role: UserRole.courier)),
    );
    await login(tester, 'courier1@rutta.test');
    expect(find.byKey(const Key('onboarding-name')), findsNothing);
    expect(find.text('My deliveries'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('use a different account signs out from onboarding', (
    tester,
  ) async {
    await pumpRutta(tester, MockAuthRepository());
    await login(tester, 'ana@rutta.test');
    await tester.tap(find.byKey(const Key('onboarding-use-different-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('demo: settings shows exit demo', (tester) async {
    await pumpRutta(tester, MockAuthRepository());
    await tester.tap(find.byKey(const Key('login-explore-demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-as-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-sign-out')), findsNothing);
    await tester.tap(find.byKey(const Key('settings-exit-demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
