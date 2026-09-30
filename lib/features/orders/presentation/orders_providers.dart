import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/features/orders/domain/order.dart';

part 'orders_providers.g.dart';

@riverpod
Stream<List<Order>> myOrders(Ref ref) =>
    ref.watch(ordersRepositoryProvider).watchMyOrders();
