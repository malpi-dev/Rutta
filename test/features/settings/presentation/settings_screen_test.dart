import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/presentation/external_links.dart';
import 'package:rutta/features/auth/data/mock_auth_repository.dart';
import 'package:rutta/features/auth/domain/demo_otp.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';
import 'package:rutta/features/auth/presentation/session_providers.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/settings/data/in_memory_settings_repository.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';
import 'package:rutta/features/settings/presentation/settings_screen.dart';
import 'package:rutta/features/settings/presentation/theme_controller.dart';
import 'package:rutta/features/tracking/presentation/location_publisher.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/demo.dart';
import '../../../helpers/location_fakes.dart';
import '../../../helpers/order_overrides.dart';
import '../../../helpers/pump_app.dart';
import '../../auth/presentation/auth_test_helpers.dart';

class _SpyAuth extends MockAuthRepository {
  _SpyAuth({super.existingProfile, super.existingProfileEmail});

  int signOuts = 0;

  @override
  Future<void> signOut() {
    signOuts++;
    return super.signOut();
  }
}

const _profile = UserProfile(
  id: 'demo-courier',
  fullName: 'Carlos Méndez',
  role: UserRole.courier,
);

void main() {
  late InMemorySettingsRepository settings;
  late List<Uri> opened;

  List<Override> base(_SpyAuth auth) => [
    settingsRepositoryProvider.overrideWithValue(settings),
    externalLinkOpenerProvider.overrideWithValue(
      (uri) async => opened.add(uri),
    ),
    ...authOverrides(auth),
  ];

  setUp(() {
    settings = InMemorySettingsRepository();
    opened = [];
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));

  Future<_SpyAuth> pumpLive(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _SpyAuth(
      existingProfile: _profile,
      existingProfileEmail: 'carlos@rutta.test',
    );
    await auth.verifyCode(email: 'carlos@rutta.test', code: demoOtpCode);
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: [...base(auth), ...extra],
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('choosing Dark updates the controller and is persisted', (
    tester,
  ) async {
    await pumpLive(tester);
    expect(
      containerOf(tester).read(themeControllerProvider),
      ThemePreference.system,
    );
    await tester.tap(find.byKey(const Key('settings-theme-dark')));
    await tester.pumpAndSettle();
    expect(
      containerOf(tester).read(themeControllerProvider),
      ThemePreference.dark,
    );
    expect(settings.loadTheme(), ThemePreference.dark);
    await tester.tap(find.byKey(const Key('settings-theme-light')));
    await tester.pumpAndSettle();
    expect(settings.loadTheme(), ThemePreference.light);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live: shows the profile and signs out after confirming', (
    tester,
  ) async {
    final auth = await pumpLive(tester);
    expect(find.text('Carlos Méndez'), findsOneWidget);
    expect(find.text('carlos@rutta.test · Courier'), findsOneWidget);
    expect(find.text('CM'), findsOneWidget);
    expect(find.byKey(const Key('settings-exit-demo')), findsNothing);

    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of Rutta?'), findsOneWidget);

    // Cancelling does nothing.
    await tester.tap(find.byKey(const Key('settings-sign-out-cancel')));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);

    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sign-out-confirm')));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
    expect(
      containerOf(tester).read(sessionStateProvider).value,
      isA<SessionSignedOut>(),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('demo: shows the role and Exit demo leaves the demo', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: base(_SpyAuth()),
    );
    containerOf(
      tester,
    ).read(appModeControllerProvider.notifier).enterDemo(UserRole.courier);
    await tester.pumpAndSettle();
    expect(find.text('Exploring the demo as Courier'), findsOneWidget);
    expect(find.byKey(const Key('settings-sign-out')), findsNothing);

    await tester.tap(find.byKey(const Key('settings-exit-demo')));
    await tester.pumpAndSettle();
    expect(
      containerOf(tester).read(appModeControllerProvider),
      isA<AppModeLive>(),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every credit opens its link', (tester) async {
    await pumpLive(tester);
    for (final text in [
      'Map data © OpenStreetMap contributors',
      'Map tiles follow the OSM tile usage policy',
      'Routes computed with OSRM',
    ]) {
      await tester.tap(find.text(text));
      await tester.pump();
    }
    expect(opened, [
      ExternalLinks.osmCopyright,
      ExternalLinks.osmTilePolicy,
      ExternalLinks.osrm,
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('licenses opens the license page', (tester) async {
    await pumpLive(tester);
    await tester.tap(find.byKey(const Key('settings-licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signing out stops the courier location sharing', (
    tester,
  ) async {
    final store = testDemoStore(role: UserRole.courier)
      ..addOrder(
        buildOrder(
          id: 'live',
          code: 'RT-9999',
          status: OrderStatus.inTransit,
          courierId: 'demo-courier',
        ),
      );
    final device = FakeDeviceLocation();
    await pumpLive(
      tester,
      extra: [
        ...screenOverrides(store, device: device),
        screenAwakeProvider.overrideWithValue(FakeScreenAwake()),
      ],
    );
    // The courier home watches these; do the same here.
    final container = containerOf(tester)
      ..listen(myOrdersProvider, (_, _) {})
      ..listen(activeDeliveryProvider, (_, _) {});
    final engine = container.read(locationPublisherProvider);
    // Let the engine read the orders and start the GPS.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(device.isWatching, isTrue);

    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sign-out-confirm')));
    await tester.pumpAndSettle();

    expect(container.read(locationPublisherProvider), isNot(same(engine)));
    expect(device.isWatching, isFalse);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
