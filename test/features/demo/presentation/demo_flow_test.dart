import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/provider_retry.dart';

import '../../../helpers/test_overrides.dart';

void main() {
  Future<void> pumpRutta(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: testOverrides(),
        child: const RuttaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String roleKey) async {
    await tester.tap(find.byKey(const Key('login-explore-demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(roleKey)));
    await tester.pumpAndSettle();
  }

  testWidgets('explore as customer, then exit demo', (tester) async {
    await pumpRutta(tester);
    expect(find.byKey(const Key('demo-banner')), findsNothing);

    await enter(tester, 'demo-as-customer');
    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    expect(find.text('Demo mode — sample data'), findsOneWidget);
    expect(find.text('RT-1042'), findsOneWidget);
    expect(find.text('RT-1031'), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-exit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-banner')), findsNothing);
    expect(find.byKey(const Key('login-explore-demo')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('explore as courier', (tester) async {
    await pumpRutta(tester);
    await enter(tester, 'demo-as-courier');
    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    expect(find.text('RT-1043'), findsOneWidget);
    expect(find.text('RT-1042'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
