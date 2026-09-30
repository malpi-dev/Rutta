import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/features/auth/data/mock_auth_repository.dart';
import 'package:rutta/features/auth/domain/demo_otp.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/auth/presentation/verify_code_screen.dart';

import '../../../helpers/pump_app.dart';
import 'auth_test_helpers.dart';

void main() {
  const email = 'me@rutta.test';

  Future<MockAuthRepository> pumpVerify(WidgetTester tester) async {
    final repo = MockAuthRepository();
    await pumpApp(
      tester,
      const VerifyCodeScreen(email: email),
      overrides: authOverrides(repo),
    );
    return repo;
  }

  testWidgets('shows the subtitle with the email', (tester) async {
    await pumpVerify(tester);
    expect(
      find.text('Enter the 6-digit code we sent to $email'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wrong code shows a readable error', (tester) async {
    await pumpVerify(tester);
    await tester.enterText(find.byKey(const Key('verify-code')), '000000');
    await tester.pumpAndSettle();
    expect(find.text('The code is invalid or has expired.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('six digits submit on their own', (tester) async {
    final repo = await pumpVerify(tester);
    final states = <SessionState>[];
    final sub = repo.watchSession().listen(states.add);
    await tester.enterText(find.byKey(const Key('verify-code')), demoOtpCode);
    await tester.pumpAndSettle();
    expect(states.last, const SessionNeedsProfile(email));
    unawaited(sub.cancel());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('only digits are accepted', (tester) async {
    await pumpVerify(tester);
    await tester.enterText(find.byKey(const Key('verify-code')), '12ab34');
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('verify-code')))
          .controller!
          .text,
      '1234',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resend is disabled for 60 s, then sends a new code', (
    tester,
  ) async {
    await pumpVerify(tester);
    TextButton resend() =>
        tester.widget<TextButton>(find.byKey(const Key('verify-resend')));
    expect(resend().onPressed, isNull);
    expect(find.text('Resend in 60s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(resend().onPressed, isNull);
    expect(find.text('Resend in 1s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(resend().onPressed, isNotNull);
    expect(find.text('Resend code'), findsOneWidget);

    await tester.tap(find.byKey(const Key('verify-resend')));
    await tester.pump();
    await tester.pump();
    expect(find.text('We sent you a new code.'), findsOneWidget);
    expect(resend().onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
