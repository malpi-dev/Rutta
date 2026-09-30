import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/order_timeline.dart';

import '../../../helpers/builders.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 30, 12);
  final t1 = t0.add(const Duration(minutes: 5));

  test('assigned: created done, assigned current, rest upcoming', () {
    final steps = buildOrderTimeline(
      current: OrderStatus.assigned,
      events: [
        buildEvent(OrderStatus.created, t0),
        buildEvent(OrderStatus.assigned, t1, id: 2),
      ],
    );
    expect(steps, [
      TimelineStep(
        status: OrderStatus.created,
        state: TimelineStepState.done,
        at: t0,
      ),
      TimelineStep(
        status: OrderStatus.assigned,
        state: TimelineStepState.current,
        at: t1,
      ),
      const TimelineStep(
        status: OrderStatus.pickedUp,
        state: TimelineStepState.upcoming,
      ),
      const TimelineStep(
        status: OrderStatus.inTransit,
        state: TimelineStepState.upcoming,
      ),
      const TimelineStep(
        status: OrderStatus.delivered,
        state: TimelineStepState.upcoming,
      ),
    ]);
  });

  test('delivered: all five steps are done', () {
    final steps = buildOrderTimeline(
      current: OrderStatus.delivered,
      events: const [],
    );
    expect(steps.map((s) => s.status), [
      OrderStatus.created,
      OrderStatus.assigned,
      OrderStatus.pickedUp,
      OrderStatus.inTransit,
      OrderStatus.delivered,
    ]);
    expect(steps.every((s) => s.state == TimelineStepState.done), isTrue);
  });

  test('cancelled from assigned: 3 steps, cancelled is current', () {
    final steps = buildOrderTimeline(
      current: OrderStatus.cancelled,
      events: [
        buildEvent(OrderStatus.created, t0),
        buildEvent(OrderStatus.assigned, t1, id: 2),
        buildEvent(
          OrderStatus.cancelled,
          t1.add(const Duration(minutes: 1)),
          id: 3,
        ),
      ],
    );
    expect(steps.map((s) => (s.status, s.state)), [
      (OrderStatus.created, TimelineStepState.done),
      (OrderStatus.assigned, TimelineStepState.done),
      (OrderStatus.cancelled, TimelineStepState.current),
    ]);
  });

  test('at uses the latest event when a status repeats', () {
    final steps = buildOrderTimeline(
      current: OrderStatus.created,
      events: [
        buildEvent(OrderStatus.created, t1, id: 2),
        buildEvent(OrderStatus.created, t0),
      ],
    );
    expect(steps.first.at, t1);
  });

  test('no events leaves at null without failing', () {
    final steps = buildOrderTimeline(
      current: OrderStatus.inTransit,
      events: const [],
    );
    expect(steps.every((s) => s.at == null), isTrue);
    expect(steps[3].state, TimelineStepState.current);
  });
}
