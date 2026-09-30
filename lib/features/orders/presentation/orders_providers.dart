import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/features/orders/domain/order.dart';

part 'orders_providers.g.dart';

@riverpod
Stream<List<Order>> myOrders(Ref ref) =>
    ref.watch(ordersRepositoryProvider).watchMyOrders();

@riverpod
Stream<Order> order(Ref ref, String orderId) =>
    ref.watch(ordersRepositoryProvider).watchOrder(orderId);

@riverpod
Stream<List<OrderStatusEvent>> orderEvents(Ref ref, String orderId) =>
    ref.watch(ordersRepositoryProvider).watchStatusEvents(orderId);

@riverpod
Stream<bool> isConnected(Ref ref) =>
    ref.watch(connectionMonitorProvider).watchIsConnected();
