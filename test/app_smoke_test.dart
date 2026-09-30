import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/provider_retry.dart';

import 'helpers/test_overrides.dart';

void main() {
  testWidgets('starts on the login screen (demo only without a backend)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: testOverrides(),
        child: const RuttaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rutta'), findsOneWidget);
    expect(find.byKey(const Key('login-explore-demo')), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
