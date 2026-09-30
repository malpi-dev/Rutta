import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';
import 'package:rutta/features/settings/presentation/theme_controller.dart';

import '../../../helpers/fake_rutta_map.dart';
import '../../../helpers/test_overrides.dart';

void main() {
  testWidgets('dark preference: dark ThemeMode and dark map', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: testOverrides(),
        child: const RuttaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(themeControllerProvider.notifier).change(ThemePreference.dark);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.byKey(const Key('login-explore-demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-as-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('order-card-RT-1042')));
    await tester.pumpAndSettle();
    expect(FakeRuttaMap.lastProps?.darkMode, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
