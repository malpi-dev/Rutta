import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/di/provider_retry.dart';

import 'helpers/test_overrides.dart';

void main() {
  testWidgets('starts on the provisional login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: testOverrides(),
        child: const RuttaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Rutta')),
      findsOneWidget,
    );
    expect(find.text('Coming soon'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
