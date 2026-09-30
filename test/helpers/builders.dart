import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

/// On the equator; each segment is about 1111.95 m long.
const straightRoute = [GeoPoint(0, 0), GeoPoint(0, 0.01), GeoPoint(0, 0.02)];

Order buildOrder({
  String id = 'o1',
  String code = 'RT-1000',
  OrderStatus status = OrderStatus.assigned,
  String customerId = 'c1',
  String? courierId = 'k1',
  List<GeoPoint> route = straightRoute,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 30, 12);
  return Order(
    id: id,
    code: code,
    customerId: customerId,
    status: status,
    pickup: const Place(
      address: 'Pickup St 1',
      point: GeoPoint(0, 0),
      name: 'Taqueria',
    ),
    dropoff: const Place(address: 'Dropoff Ave 2', point: GeoPoint(0, 0.02)),
    items: const [OrderItem(name: 'Tacos', quantity: 3)],
    totalCents: 24500,
    route: route,
    routeDistanceMeters: 2224,
    routeDurationSeconds: 480,
    createdAt: created,
    updatedAt: created,
    courierId: courierId,
  );
}

OrderStatusEvent buildEvent(
  OrderStatus status,
  DateTime at, {
  int id = 1,
  String orderId = 'o1',
}) => OrderStatusEvent(
  id: id,
  orderId: orderId,
  status: status,
  createdAt: at,
);

DevicePosition buildPosition(
  GeoPoint point,
  DateTime at, {
  double? accuracy,
  double? speed,
}) => DevicePosition(
  point: point,
  timestamp: at,
  accuracyMeters: accuracy,
  speedMps: speed,
);
