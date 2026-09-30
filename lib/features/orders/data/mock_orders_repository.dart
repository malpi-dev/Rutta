import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_store.dart';
import 'package:rutta/features/demo/data/demo_stream.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';

class MockOrdersRepository implements OrdersRepository {
  MockOrdersRepository(this._store);

  final DemoStore _store;

  @override
  Stream<List<Order>> watchMyOrders() =>
      watchStore(_store, _store.ordersForCurrentUser);

  @override
  Stream<Order> watchOrder(String orderId) => watchStore(
    _store,
    () => _store.order(orderId) ?? (throw NotFoundError('order', orderId)),
  );

  @override
  Stream<List<OrderStatusEvent>> watchStatusEvents(String orderId) =>
      watchStore(_store, () => _store.events(orderId));

  @override
  Future<Order> advanceStatus(String orderId, OrderStatus next) async {
    await Future<void>.delayed(_store.latency);
    return _store.advance(orderId, next, actorId: _store.currentUserId);
  }
}
