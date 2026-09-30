import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/orders/data/order_mapper.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

Map<String, dynamic> _row() => {
  'id': 'o1',
  'code': 'RT-1042',
  'customer_id': 'c1',
  'courier_id': 'k1',
  'status': 'in_transit',
  'pickup_name': 'Taqueria Uno',
  'pickup_address': 'Calle 1',
  'pickup_lat': 19.4,
  'pickup_lng': -99.1,
  'dropoff_address': 'Calle 2',
  'dropoff_lat': 19,
  'dropoff_lng': -99,
  'items': [
    {'name': 'Tacos', 'quantity': 3},
  ],
  'total_cents': 24500,
  'route': [
    [-99.1, 19.4],
    [-99.0, 19.0],
  ],
  'route_distance_m': 2362,
  'route_duration_s': 600,
  'created_at': '2026-09-30T20:00:00+00:00',
  'updated_at': '2026-09-30T20:30:00.123456+00:00',
  'courier': {'full_name': 'Carlos'},
  'customer': {'full_name': 'Alex'},
};

void main() {
  test('maps a full row (route is [lng, lat])', () {
    final order = orderFromRow(_row());
    expect(order.code, 'RT-1042');
    expect(order.status, OrderStatus.inTransit);
    expect(order.route.first, const GeoPoint(19.4, -99.1));
    expect(order.route.last, const GeoPoint(19, -99));
    expect(order.pickup.name, 'Taqueria Uno');
    expect(order.dropoff.name, isNull);
    expect(order.dropoff.point, const GeoPoint(19, -99));
    expect(order.items.single.quantity, 3);
    expect(order.totalCents, 24500);
    expect(order.routeDistanceMeters, 2362);
    expect(order.createdAt.isUtc, isTrue);
    expect(order.updatedAt, DateTime.utc(2026, 9, 30, 20, 30, 0, 123, 456));
    expect(order.courierName, 'Carlos');
    expect(order.customerName, 'Alex');
  });

  test('null courier gives null courier fields', () {
    final order = orderFromRow(
      _row()
        ..['courier_id'] = null
        ..['courier'] = null,
    );
    expect(order.courierId, isNull);
    expect(order.courierName, isNull);
  });

  test('missing key or wrong type is an UnknownError', () {
    expect(
      () => orderFromRow(_row()..remove('total_cents')),
      throwsA(isA<UnknownError>()),
    );
    expect(
      () => orderFromRow(_row()..['status'] = 'flying'),
      throwsA(isA<UnknownError>()),
    );
    expect(
      () => orderFromRow(_row()..['pickup_lat'] = 'x'),
      throwsA(isA<UnknownError>()),
    );
  });

  test('maps a status event', () {
    final event = statusEventFromRow({
      'id': 7,
      'order_id': 'o1',
      'status': 'picked_up',
      'created_at': '2026-09-30T20:10:00+00:00',
    });
    expect(event.id, 7);
    expect(event.status, OrderStatus.pickedUp);
    expect(event.createdAt, DateTime.utc(2026, 9, 30, 20, 10));
    expect(
      () => statusEventFromRow({'id': 1}),
      throwsA(isA<UnknownError>()),
    );
  });
}
