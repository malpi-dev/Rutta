import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

abstract interface class OrdersRepository {
  /// Customer: their orders. Courier: orders assigned to them. Newest first
  /// (createdAt desc). Emits again whenever any of those orders changes.
  Stream<List<Order>> watchMyOrders();

  /// Emits the order and every later change. Errors with `NotFoundError` if it
  /// does not exist or is not visible.
  Stream<Order> watchOrder(String orderId);

  /// Status history ordered by createdAt ascending.
  Stream<List<OrderStatusEvent>> watchStatusEvents(String orderId);

  /// Courier only. Throws `InvalidTransitionError`, `NotAssignedToYouError`,
  /// `CourierBusyError`, `NotFoundError`, `NetworkError`... Returns the updated
  /// order.
  Future<Order> advanceStatus(String orderId, OrderStatus next);
}
