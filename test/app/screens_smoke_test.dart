// Visual smoke test: every main screen builds without exceptions or overflow
// in light and dark, on a small and a regular phone, at 1.0x and 1.3x text.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/map/rutta_map_provider.dart';
import 'package:rutta/core/presentation/root_scaffold_messenger.dart';
import 'package:rutta/core/router/app_router.dart';
import 'package:rutta/core/router/routes.dart';
import 'package:rutta/core/theme/app_theme.dart';
import 'package:rutta/features/auth/data/mock_auth_repository.dart';
import 'package:rutta/features/auth/domain/demo_otp.dart';
import 'package:rutta/features/auth/presentation/onboarding_screen.dart';
import 'package:rutta/features/auth/presentation/verify_code_screen.dart';
import 'package:rutta/features/location_permission/presentation/location_permission_sheet.dart';
import 'package:rutta/features/settings/data/in_memory_settings_repository.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';
import 'package:rutta/l10n/app_localizations.dart';

import '../features/auth/presentation/auth_test_helpers.dart';
import '../helpers/fake_rutta_map.dart';
import '../helpers/location_fakes.dart';

const Map<String, Size> _sizes = {
  '360x640': Size(360, 640),
  '411x891': Size(411, 891),
};
const Map<String, ThemePreference> _themes = {
  'light': ThemePreference.light,
  'dark': ThemePreference.dark,
};

void _configureView(WidgetTester tester, Size size, double scale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  for (final theme in _themes.entries) {
    for (final size in _sizes.entries) {
      for (final scale in [1.0, 1.3]) {
        final label = '${theme.key} ${size.key} x$scale';

        testWidgets('app screens, $label', (tester) async {
          _configureView(tester, size.value, scale);
          await tester.pumpWidget(
            ProviderScope(
              retry: noAutomaticRetry,
              overrides: [
                settingsRepositoryProvider.overrideWithValue(
                  InMemorySettingsRepository(theme.value),
                ),
                clockProvider.overrideWithValue(
                  FixedClock(DateTime.utc(2026, 10, 7, 18)),
                ),
                ruttaMapBuilderProvider.overrideWithValue(FakeRuttaMap.new),
              ],
              child: const RuttaApp(),
            ),
          );
          await tester.pumpAndSettle();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(RuttaApp)),
          );
          expect(find.byKey(const Key('login-explore-demo')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'Login at $label');

          // Demo role picker sheet.
          await tester.tap(find.byKey(const Key('login-explore-demo')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('demo-as-courier')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'Picker at $label');

          final notifier = container.read(appModeControllerProvider.notifier);
          final router = container.read(appRouterProvider);

          Future<void> visit(String name, String path) async {
            router.go(path);
            await tester.pumpAndSettle();
            expect(
              router.routerDelegate.currentConfiguration.uri.path,
              path,
              reason: 'navigated to $name',
            );
            expect(tester.takeException(), isNull, reason: '$name at $label');
          }

          await tester.tap(find.byKey(const Key('demo-as-customer')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('demo-banner')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'Customer list');
          await visit(
            'Customer in transit',
            '/customer/orders/demo-order-1042',
          );
          await visit('Customer assigned', '/customer/orders/demo-order-1043');
          await visit('Customer delivered', '/customer/orders/demo-order-1038');
          await visit('Customer cancelled', '/customer/orders/demo-order-1031');
          await visit('Settings (customer)', Routes.settings);

          notifier.exitDemo();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('login-explore-demo')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('demo-as-courier')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Courier list');
          await visit('Courier assigned', '/courier/orders/demo-order-1043');
          await visit('Courier delivered', '/courier/orders/demo-order-1029');
          await visit('Settings (courier)', Routes.settings);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('auth screens, $label', (tester) async {
          _configureView(tester, size.value, scale);
          final auth = MockAuthRepository();
          await auth.sendCode('ana@rutta.test');
          await auth.verifyCode(email: 'ana@rutta.test', code: demoOtpCode);
          for (final (name, screen) in <(String, Widget)>[
            ('Verify', const VerifyCodeScreen(email: 'ana@rutta.test')),
            ('Onboarding', const OnboardingScreen()),
          ]) {
            await tester.pumpWidget(
              ProviderScope(
                retry: noAutomaticRetry,
                overrides: authOverrides(auth),
                child: MaterialApp(
                  theme: theme.value == ThemePreference.dark
                      ? AppTheme.dark()
                      : AppTheme.light(),
                  scaffoldMessengerKey: rootScaffoldMessengerKey,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: screen,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$name at $label');
            await tester.pumpWidget(const SizedBox());
          }
        });

        for (final access in [
          LocationAccess.denied,
          LocationAccess.deniedForever,
          LocationAccess.serviceDisabled,
        ]) {
          testWidgets('permission sheet ${access.name}, $label', (
            tester,
          ) async {
            _configureView(tester, size.value, scale);
            await tester.pumpWidget(
              ProviderScope(
                retry: noAutomaticRetry,
                overrides: [
                  deviceLocationRepositoryProvider.overrideWithValue(
                    FakeDeviceLocation(access: access),
                  ),
                ],
                child: MaterialApp(
                  theme: theme.value == ThemePreference.dark
                      ? AppTheme.dark()
                      : AppTheme.light(),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Consumer(
                    builder: (context, ref, _) => FilledButton(
                      key: const Key('open'),
                      onPressed: () => ensureLocationAccess(context, ref),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.byKey(const Key('open')));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsOneWidget);
            expect(tester.takeException(), isNull, reason: '$access at $label');
            await tester.pumpWidget(const SizedBox());
          });
        }
      }
    }
  }
}
