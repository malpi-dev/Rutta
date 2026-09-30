import 'package:meta/meta.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

enum TimelineStepState { done, current, upcoming }

@immutable
class TimelineStep {
  const TimelineStep({required this.status, required this.state, this.at});

  final OrderStatus status;
  final TimelineStepState state;

  /// Time of the latest event with this status, if any.
  final DateTime? at;

  @override
  bool operator ==(Object other) =>
      other is TimelineStep &&
      other.status == status &&
      other.state == state &&
      other.at == at;

  @override
  int get hashCode => Object.hash(status, state, at);

  @override
  String toString() => 'TimelineStep($status, $state, $at)';
}

const List<OrderStatus> _happyPath = [
  OrderStatus.created,
  OrderStatus.assigned,
  OrderStatus.pickedUp,
  OrderStatus.inTransit,
  OrderStatus.delivered,
];

List<TimelineStep> buildOrderTimeline({
  required OrderStatus current,
  required List<OrderStatusEvent> events,
}) {
  // Latest event time per status (later events win).
  final at = <OrderStatus, DateTime>{};
  for (final e in events) {
    final previous = at[e.status];
    if (previous == null || e.createdAt.isAfter(previous)) {
      at[e.status] = e.createdAt;
    }
  }

  if (current == OrderStatus.cancelled) {
    return [
      for (final s in _happyPath)
        if (at.containsKey(s))
          TimelineStep(status: s, state: TimelineStepState.done, at: at[s]),
      TimelineStep(
        status: OrderStatus.cancelled,
        state: TimelineStepState.current,
        at: at[OrderStatus.cancelled],
      ),
    ];
  }

  final currentIndex = _happyPath.indexOf(current);
  return [
    for (var i = 0; i < _happyPath.length; i++)
      TimelineStep(
        status: _happyPath[i],
        state: i < currentIndex || current == OrderStatus.delivered
            ? TimelineStepState.done
            : i == currentIndex
            ? TimelineStepState.current
            : TimelineStepState.upcoming,
        at: at[_happyPath[i]],
      ),
  ];
}
