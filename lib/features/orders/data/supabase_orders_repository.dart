import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/supabase/live_query.dart';
import 'package:rutta/core/supabase/realtime_status_hub.dart';
import 'package:rutta/core/supabase/supabase_error_mapper.dart';
import 'package:rutta/features/orders/data/order_mapper.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOrdersRepository implements OrdersRepository {
  SupabaseOrdersRepository(
    this._client,
    this._hub, {
    required this._userId,
    required this._role,
  });

  final SupabaseClient _client;
  final RealtimeStatusHub _hub;
  final String _userId;
  final UserRole _role;

  SupabaseQuerySchema get _db => _client.schema('rutta');

  String get _roleColumn =>
      _role == UserRole.customer ? 'customer_id' : 'courier_id';

  @override
  Stream<List<Order>> watchMyOrders() => liveQuery<List<Order>>(
    client: _client,
    hub: _hub,
    channelName: nextChannelName('orders', _userId),
    fetch: () => guardSupabase(() async {
      final rows = await _db
          .from('orders')
          .select(orderColumns)
          .eq(_roleColumn, _userId)
          .order('created_at', ascending: false);
      return rows.map(orderFromRow).toList();
    }),
    bind: (channel, refetch, _) => channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'rutta',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: _roleColumn,
        value: _userId,
      ),
      callback: (_) => refetch(),
    ),
  );

  Future<Order> _fetchOrder(String id) => guardSupabase(() async {
    final row = await _db
        .from('orders')
        .select(orderColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) throw NotFoundError('order', id);
    return orderFromRow(row);
  });

  @override
  Stream<Order> watchOrder(String orderId) => liveQuery<Order>(
    client: _client,
    hub: _hub,
    channelName: nextChannelName('order', orderId),
    fetch: () => _fetchOrder(orderId),
    bind: (channel, refetch, _) => channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'rutta',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: orderId,
      ),
      callback: (_) => refetch(),
    ),
  );

  @override
  Stream<List<OrderStatusEvent>> watchStatusEvents(String orderId) =>
      liveQuery<List<OrderStatusEvent>>(
        client: _client,
        hub: _hub,
        channelName: nextChannelName('events', orderId),
        fetch: () => guardSupabase(() async {
          final rows = await _db
              .from('order_status_events')
              .select('id, order_id, status, created_at')
              .eq('order_id', orderId)
              .order('created_at', ascending: true);
          return rows.map(statusEventFromRow).toList();
        }),
        bind: (channel, refetch, _) => channel.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'rutta',
          table: 'order_status_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (_) => refetch(),
        ),
      );

  @override
  Future<Order> advanceStatus(String orderId, OrderStatus next) async {
    await guardSupabase(
      () => _db.rpc<dynamic>(
        'advance_order_status',
        params: {'p_order_id': orderId, 'p_next': next.wireName},
      ),
    );
    // The RPC returns the bare row: re-read to get the embedded names.
    return _fetchOrder(orderId);
  }
}
