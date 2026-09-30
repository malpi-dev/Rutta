import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/features/orders/data/mock_connection_monitor.dart';
import 'package:rutta/features/orders/presentation/widgets/reconnecting_banner.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('shows the banner while disconnected and hides it after', (
    tester,
  ) async {
    final controller = StreamController<bool>();
    addTearDown(controller.close);
    await pumpApp(
      tester,
      const Scaffold(body: ReconnectingBanner()),
      overrides: [
        connectionMonitorProvider.overrideWithValue(
          MockConnectionMonitor.controlled(controller),
        ),
      ],
    );
    final banner = find.byKey(const Key('reconnecting-banner'));

    controller.add(false);
    await tester.pump();
    expect(banner, findsOneWidget);

    controller.add(true);
    await tester.pump();
    expect(banner, findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
