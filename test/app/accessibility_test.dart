// Tap targets (>= 48 dp) and text contrast on the key screens, in both themes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/router/app_router.dart';
import 'package:rutta/core/router/routes.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';

import '../helpers/test_overrides.dart';

void main() {
  for (final theme in [ThemePreference.light, ThemePreference.dark]) {
    testWidgets('key screens meet the a11y guidelines, ${theme.name}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: noAutomaticRetry,
          overrides: [
            ...testOverrides(theme: theme),
          ],
          child: const RuttaApp(),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> check(String name) async {
        await expectLater(
          tester,
          meetsGuideline(androidTapTargetGuideline),
          reason: '$name tap targets',
        );
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: '$name contrast',
        );
      }

      await check('Login');
      await tester.tap(find.byKey(const Key('login-explore-demo')));
      await tester.pumpAndSettle();
      await check('Demo picker');
      await tester.tap(find.byKey(const Key('demo-as-customer')));
      await tester.pumpAndSettle();
      await check('Customer list');

      final router = ProviderScope.containerOf(
        tester.element(find.byType(RuttaApp)),
      ).read(appRouterProvider);
      for (final (name, path) in [
        ('Customer detail', '/customer/orders/demo-order-1042'),
        ('Settings', Routes.settings),
        ('Delivered detail', '/customer/orders/demo-order-1038'),
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        await check(name);
      }

      await tester.tap(find.byKey(const Key('demo-exit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('login-explore-demo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-as-courier')));
      await tester.pumpAndSettle();
      await check('Courier list');
      router.go('/courier/orders/demo-order-1043');
      await tester.pumpAndSettle();
      await check('Courier detail');
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
