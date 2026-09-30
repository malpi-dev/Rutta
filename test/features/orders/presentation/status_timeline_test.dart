import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/theme/app_theme.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/order_timeline.dart';
import 'package:rutta/features/orders/presentation/widgets/status_timeline.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/pump_app.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 30, 20);

  double opacityOf(WidgetTester tester, String key) =>
      tester.widget<Opacity>(find.byKey(Key('timeline-$key'))).opacity;

  testWidgets('done steps show time, current is bold, upcoming is dimmed', (
    tester,
  ) async {
    final steps = buildOrderTimeline(
      current: OrderStatus.assigned,
      events: [
        buildEvent(OrderStatus.created, t0),
        buildEvent(
          OrderStatus.assigned,
          t0.add(const Duration(minutes: 4)),
          id: 2,
        ),
      ],
    );
    await pumpApp(tester, Scaffold(body: StatusTimeline(steps: steps)));

    expect(find.text('Placed'), findsOneWidget);
    expect(find.text('Courier assigned'), findsOneWidget);
    expect(opacityOf(tester, 'created'), 1);
    expect(opacityOf(tester, 'assigned'), 1);
    expect(opacityOf(tester, 'picked_up'), 0.45);
    expect(opacityOf(tester, 'delivered'), 0.45);

    final current = tester.widget<Text>(find.text('Courier assigned'));
    expect(current.style?.fontWeight, FontWeight.w600);

    // Only the two reached steps have a time.
    final row = find.byKey(const Key('timeline-picked_up'));
    expect(
      find.descendant(of: row, matching: find.textContaining(RegExp('[AP]M'))),
      findsNothing,
    );
    final created = find.byKey(const Key('timeline-created'));
    expect(
      find.descendant(
        of: created,
        matching: find.textContaining(RegExp('[AP]M')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelled step uses the error color', (tester) async {
    final steps = buildOrderTimeline(
      current: OrderStatus.cancelled,
      events: [
        buildEvent(OrderStatus.created, t0),
        buildEvent(
          OrderStatus.cancelled,
          t0.add(const Duration(minutes: 5)),
          id: 2,
        ),
      ],
    );
    await pumpApp(tester, Scaffold(body: StatusTimeline(steps: steps)));

    final text = tester.widget<Text>(find.text('Cancelled'));
    expect(text.style?.color, AppTheme.light().colorScheme.error);
    expect(find.byKey(const Key('timeline-delivered')), findsNothing);
  });
}
