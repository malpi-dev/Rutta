import 'package:meta/meta.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

enum OrderAction {
  pickUp(OrderStatus.pickedUp),
  startDelivery(OrderStatus.inTransit),
  markDelivered(OrderStatus.delivered);

  const OrderAction(this.target);

  final OrderStatus target;
}

enum ActionBlockReason { courierBusy }

@immutable
class OrderActionState {
  const OrderActionState(this.action, {this.blockReason});

  final OrderAction action;
  final ActionBlockReason? blockReason;

  bool get enabled => blockReason == null;

  @override
  bool operator ==(Object other) =>
      other is OrderActionState &&
      other.action == action &&
      other.blockReason == blockReason;

  @override
  int get hashCode => Object.hash(action, blockReason);

  @override
  String toString() => 'OrderActionState($action, $blockReason)';
}

class AvailableOrderActions {
  const AvailableOrderActions();

  /// Primary action for the detail screen, or null when there is none.
  OrderActionState? call({
    required UserRole role,
    required OrderStatus status,
    required bool hasOtherOrderInProgress,
  }) {
    if (role != UserRole.courier) return null;
    return switch (status) {
      OrderStatus.assigned => OrderActionState(
        OrderAction.pickUp,
        blockReason: hasOtherOrderInProgress
            ? ActionBlockReason.courierBusy
            : null,
      ),
      OrderStatus.pickedUp => const OrderActionState(OrderAction.startDelivery),
      OrderStatus.inTransit => const OrderActionState(
        OrderAction.markDelivered,
      ),
      OrderStatus.created ||
      OrderStatus.delivered ||
      OrderStatus.cancelled => null,
    };
  }
}

/// True if [orders] contains an order other than [currentOrderId] in
/// picked_up / in_transit.
bool hasOtherOrderInProgress(List<Order> orders, String currentOrderId) =>
    orders.any((o) => o.id != currentOrderId && o.status.isInProgress);
