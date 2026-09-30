import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/features/location_permission/presentation/location_permission_sheet.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

import '../../../helpers/location_fakes.dart';
import '../../../helpers/pump_app.dart';

/// The app goes to the background (system dialog / settings) and comes back.
void backgroundAndBack(WidgetTester tester) {
  const path = <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];
  // ignore: prefer_foreach, a tear-off would trip cascade_invocations.
  for (final state in path) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  late LocationAccess? result;

  Future<FakeDeviceLocation> open(
    WidgetTester tester,
    LocationAccess access, {
    LocationAccess? afterRequest,
  }) async {
    result = null;
    final device = FakeDeviceLocation(access: access)
      ..accessAfterRequest = afterRequest;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) => Center(
          child: FilledButton(
            key: const Key('open'),
            onPressed: () async =>
                result = await ensureLocationAccess(context, ref),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [deviceLocationRepositoryProvider.overrideWithValue(device)],
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return device;
  }

  testWidgets('granted: no sheet is shown', (tester) async {
    await open(tester, LocationAccess.granted);
    expect(find.text('Share your location'), findsNothing);
    expect(result, LocationAccess.granted);
  });

  testWidgets('denied: explains, Continue requests and closes when granted', (
    tester,
  ) async {
    final device = await open(
      tester,
      LocationAccess.denied,
      afterRequest: LocationAccess.granted,
    );
    expect(find.text('Share your location'), findsOneWidget);
    expect(find.textContaining('only while a delivery'), findsOneWidget);

    await tester.tap(find.byKey(const Key('permission-continue')));
    await tester.pumpAndSettle();
    expect(device.requestCalls, 1);
    expect(find.text('Share your location'), findsNothing);
    expect(result, LocationAccess.granted);
  });

  testWidgets('denied again: the sheet stays open', (tester) async {
    final device = await open(tester, LocationAccess.denied);
    await tester.tap(find.byKey(const Key('permission-continue')));
    await tester.pumpAndSettle();
    expect(device.requestCalls, 1);
    expect(find.text('Share your location'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('denied then blocked: switches to Open app settings', (
    tester,
  ) async {
    await open(
      tester,
      LocationAccess.denied,
      afterRequest: LocationAccess.deniedForever,
    );
    await tester.tap(find.byKey(const Key('permission-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Location is blocked'), findsOneWidget);
    expect(find.byKey(const Key('permission-open-settings')), findsOneWidget);
  });

  testWidgets('deniedForever: Open app settings opens the settings', (
    tester,
  ) async {
    final device = await open(tester, LocationAccess.deniedForever);
    expect(find.text('Location is blocked'), findsOneWidget);
    await tester.tap(find.byKey(const Key('permission-open-settings')));
    await tester.pump();
    expect(device.openAppSettingsCalls, 1);
  });

  testWidgets('serviceDisabled: Open location settings', (tester) async {
    final device = await open(tester, LocationAccess.serviceDisabled);
    expect(find.text('Location services are off'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('permission-open-location-settings')),
    );
    await tester.pump();
    expect(device.openLocationSettingsCalls, 1);
  });

  testWidgets('Not now returns the current access', (tester) async {
    await open(tester, LocationAccess.deniedForever);
    await tester.tap(find.byKey(const Key('permission-not-now')));
    await tester.pumpAndSettle();
    expect(find.text('Location is blocked'), findsNothing);
    expect(result, LocationAccess.deniedForever);
  });

  testWidgets('coming back from settings with access granted closes it', (
    tester,
  ) async {
    final device = await open(tester, LocationAccess.deniedForever);
    device.access = LocationAccess.granted;
    backgroundAndBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('Location is blocked'), findsNothing);
    expect(result, LocationAccess.granted);
  });

  testWidgets('a resume and a request both granting pop only once', (
    tester,
  ) async {
    final device = await open(
      tester,
      LocationAccess.denied,
      afterRequest: LocationAccess.granted,
    );
    await tester.tap(find.byKey(const Key('permission-continue')));
    // The system dialog also triggers a resume while the request completes.
    backgroundAndBack(tester);
    await tester.pumpAndSettle();
    expect(device.requestCalls, 1);
    // The page under the sheet is still there.
    expect(find.byKey(const Key('open')), findsOneWidget);
  });
}
