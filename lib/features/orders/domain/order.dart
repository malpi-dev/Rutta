import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

part 'order.freezed.dart';

@freezed
abstract class Place with _$Place {
  const factory Place({
    required String address,
    required GeoPoint point,
    String? name,
  }) = _Place;
}

@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({required String name, required int quantity}) =
      _OrderItem;
}

@freezed
abstract class Order with _$Order {
  const factory Order({
    required String id,

    /// Human-readable code, e.g. `RT-1042`.
    required String code,
    required String customerId,
    required OrderStatus status,
    required Place pickup,
    required Place dropoff,
    required List<OrderItem> items,

    /// MXN cents.
    required int totalCents,

    /// Precomputed polyline, at least 2 points.
    required List<GeoPoint> route,
    required int routeDistanceMeters,
    required int routeDurationSeconds,

    /// UTC.
    required DateTime createdAt,

    /// UTC.
    required DateTime updatedAt,
    String? courierId,
    String? courierName,
    String? customerName,
  }) = _Order;
}

@freezed
abstract class OrderStatusEvent with _$OrderStatusEvent {
  const factory OrderStatusEvent({
    required int id,
    required String orderId,
    required OrderStatus status,

    /// Server time, UTC.
    required DateTime createdAt,
  }) = _OrderStatusEvent;
}
