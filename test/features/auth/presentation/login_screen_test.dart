import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rutta/features/auth/data/mock_auth_repository.dart';
import 'package:rutta/features/auth/presentation/login_screen.dart';

import '../../../helpers/pump_app.dart';
import 'auth_test_helpers.dart';

void main() {
  final routes = [
    GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/verify',
      builder: (_, s) =>
          Text('verify:${s.uri.queryParameters['email']}', key: const Key('v')),
    ),
  ];

  testWidgets('invalid email shows an error under the field', (tester) async {
    await pumpRoutes(
      tester,
      routes: routes,
      overrides: authOverrides(MockAuthRepository()),
    );
    await tester.enterText(find.byKey(const Key('login-email')), 'nope');
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.byKey(const Key('v')), findsNothing);
  });

  testWidgets('a valid email navigates to /verify?email=', (tester) async {
    await pumpRoutes(
      tester,
      routes: routes,
      overrides: authOverrides(MockAuthRepository()),
    );
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'me@rutta.test',
    );
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pumpAndSettle();
    expect(find.text('verify:me@rutta.test'), findsOneWidget);
  });

  testWidgets('the button is disabled while sending', (tester) async {
    await pumpRoutes(
      tester,
      routes: routes,
      overrides: authOverrides(
        MockAuthRepository(latency: const Duration(seconds: 1)),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'me@rutta.test',
    );
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('login-send-code')),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('without backend: demo notice and no email field', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: authOverrides(MockAuthRepository(), backend: false),
    );
    expect(
      find.text(
        'This build has no backend configured. Explore the demo to try Rutta.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('login-email')), findsNothing);
    expect(find.byKey(const Key('login-send-code')), findsNothing);
    expect(find.byKey(const Key('login-explore-demo')), findsOneWidget);
  });

  testWidgets('shows the Rutta logo', (tester) async {
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: authOverrides(MockAuthRepository(), backend: false),
    );
    final logo = tester.widgetList<Image>(find.byType(Image)).single;
    expect(
      (logo.image as AssetImage).assetName,
      'assets/icon/splash_logo.png',
    );
  });
}
