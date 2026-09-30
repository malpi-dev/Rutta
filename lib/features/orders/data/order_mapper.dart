import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

/// Columns requested for every order query. Both FKs point to profiles, so
/// the embed needs the FK name.
const orderColumns =
    '*, courier:profiles!orders_courier_id_fkey(full_name), '
    'customer:profiles!orders_customer_id_fkey(full_name)';

/// `rutta.orders` row (with embedded profiles) -> [Order]. Unexpected shapes
/// are an [UnknownError].
Order orderFromRow(Map<String, dynamic> row) {
  try {
    final courier = row['courier'] as Map<String, dynamic>?;
    final customer = row['customer'] as Map<String, dynamic>?;
    return Order(
      id: row['id'] as String,
      code: row['code'] as String,
      customerId: row['customer_id'] as String,
      courierId: row['courier_id'] as String?,
      courierName: courier?['full_name'] as String?,
      customerName: customer?['full_name'] as String?,
      status: OrderStatus.fromWire(row['status'] as String),
      pickup: Place(
        name: row['pickup_name'] as String?,
        address: row['pickup_address'] as String,
        point: GeoPoint(
          (row['pickup_lat'] as num).toDouble(),
          (row['pickup_lng'] as num).toDouble(),
        ),
      ),
      dropoff: Place(
        address: row['dropoff_address'] as String,
        point: GeoPoint(
          (row['dropoff_lat'] as num).toDouble(),
          (row['dropoff_lng'] as num).toDouble(),
        ),
      ),
      items: [
        for (final item in row['items'] as List<dynamic>)
          OrderItem(
            name: (item as Map<String, dynamic>)['name'] as String,
            quantity: (item['quantity'] as num).toInt(),
          ),
      ],
      totalCents: (row['total_cents'] as num).toInt(),
      // GeoJSON order in the database: [lng, lat].
      route: [
        for (final p in row['route'] as List<dynamic>)
          GeoPoint(
            ((p as List<dynamic>)[1] as num).toDouble(),
            (p[0] as num).toDouble(),
          ),
      ],
      routeDistanceMeters: (row['route_distance_m'] as num).toInt(),
      routeDurationSeconds: (row['route_duration_s'] as num).toInt(),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  } on Object catch (error) {
    throw UnknownError(error);
  }
}

OrderStatusEvent statusEventFromRow(Map<String, dynamic> row) {
  try {
    return OrderStatusEvent(
      id: (row['id'] as num).toInt(),
      orderId: row['order_id'] as String,
      status: OrderStatus.fromWire(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  } on Object catch (error) {
    throw UnknownError(error);
  }
}
