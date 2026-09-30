import 'package:rutta/features/orders/data/demo_routes.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

abstract final class DemoUsers {
  /// Alex Rivera: the user when exploring as customer.
  static const customerId = 'demo-customer';
  static const customerName = 'Alex Rivera';

  /// Carlos Méndez: the user when exploring as courier.
  static const courierId = 'demo-courier';
  static const courierName = 'Carlos Méndez';

  /// María López: simulated courier of RT-1042.
  static const otherCourierId = 'demo-courier-2';
  static const otherCourierName = 'María López';
  static const otherCustomerId = 'demo-customer-2';
  static const otherCustomerName = 'Jordan Lee';
}

typedef DemoWorld = ({List<Order> orders, List<OrderStatusEvent> events});

/// Sample data of the demo, with event times relative to [nowUtc].
DemoWorld buildDemoWorld(DateTime nowUtc) {
  final orders = <Order>[];
  final events = <OrderStatusEvent>[];
  var nextEventId = 1;

  void add({
    required int number,
    required String routeKey,
    required String customerId,
    required String customerName,
    required List<OrderItem> items,
    required int totalCents,
    required List<(OrderStatus, int)> history,
    String? courierId,
    String? courierName,
  }) {
    final route = demoRoutes[routeKey]!;
    final id = 'demo-order-$number';
    final orderEvents = [
      for (final (status, minutes) in history)
        OrderStatusEvent(
          id: nextEventId++,
          orderId: id,
          status: status,
          createdAt: nowUtc.add(Duration(minutes: minutes)),
        ),
    ];
    events.addAll(orderEvents);
    orders.add(
      Order(
        id: id,
        code: 'RT-$number',
        customerId: customerId,
        customerName: customerName,
        courierId: courierId,
        courierName: courierName,
        status: orderEvents.last.status,
        pickup: Place(
          address: route.pickupAddress,
          point: route.pickup,
          name: route.pickupName,
        ),
        dropoff: Place(address: route.dropoffAddress, point: route.dropoff),
        items: items,
        totalCents: totalCents,
        route: route.points,
        routeDistanceMeters: route.distanceMeters,
        routeDurationSeconds: route.durationSeconds,
        createdAt: orderEvents.first.createdAt,
        updatedAt: orderEvents.last.createdAt,
      ),
    );
  }

  add(
    number: 1042,
    routeKey: 'r1',
    customerId: DemoUsers.customerId,
    customerName: DemoUsers.customerName,
    courierId: DemoUsers.otherCourierId,
    courierName: DemoUsers.otherCourierName,
    items: const [
      OrderItem(name: 'Flat white', quantity: 2),
      OrderItem(name: 'Butter croissant', quantity: 1),
    ],
    totalCents: 18500,
    history: const [
      (OrderStatus.created, -25),
      (OrderStatus.assigned, -22),
      (OrderStatus.pickedUp, -12),
      (OrderStatus.inTransit, -8),
    ],
  );
  add(
    number: 1043,
    routeKey: 'r2',
    customerId: DemoUsers.customerId,
    customerName: DemoUsers.customerName,
    courierId: DemoUsers.courierId,
    courierName: DemoUsers.courierName,
    items: const [
      OrderItem(name: 'Ibuprofen 400 mg', quantity: 1),
      OrderItem(name: 'Electrolyte drink', quantity: 2),
    ],
    totalCents: 24900,
    history: const [(OrderStatus.created, -10), (OrderStatus.assigned, -6)],
  );
  add(
    number: 1038,
    routeKey: 'r3',
    customerId: DemoUsers.customerId,
    customerName: DemoUsers.customerName,
    courierId: DemoUsers.otherCourierId,
    courierName: DemoUsers.otherCourierName,
    items: const [
      OrderItem(name: 'Quinoa bowl', quantity: 1),
      OrderItem(name: 'Green juice', quantity: 1),
    ],
    totalCents: 21000,
    history: const [
      (OrderStatus.created, -1490),
      (OrderStatus.assigned, -1487),
      (OrderStatus.pickedUp, -1475),
      (OrderStatus.inTransit, -1472),
      (OrderStatus.delivered, -1456),
    ],
  );
  add(
    number: 1035,
    routeKey: 'r4',
    customerId: DemoUsers.customerId,
    customerName: DemoUsers.customerName,
    courierId: DemoUsers.courierId,
    courierName: DemoUsers.courierName,
    items: const [
      OrderItem(name: 'Concha', quantity: 6),
      OrderItem(name: 'Café de olla', quantity: 1),
    ],
    totalCents: 13500,
    history: const [
      (OrderStatus.created, -2930),
      (OrderStatus.assigned, -2926),
      (OrderStatus.pickedUp, -2915),
      (OrderStatus.inTransit, -2911),
      (OrderStatus.delivered, -2890),
    ],
  );
  add(
    number: 1031,
    routeKey: 'r5',
    customerId: DemoUsers.customerId,
    customerName: DemoUsers.customerName,
    items: const [OrderItem(name: 'Vitamin C 1 g', quantity: 1)],
    totalCents: 9900,
    history: const [
      (OrderStatus.created, -4330),
      (OrderStatus.cancelled, -4325),
    ],
  );
  add(
    number: 1029,
    routeKey: 'r6',
    customerId: DemoUsers.otherCustomerId,
    customerName: DemoUsers.otherCustomerName,
    courierId: DemoUsers.courierId,
    courierName: DemoUsers.courierName,
    items: const [OrderItem(name: 'Salmon poke bowl', quantity: 1)],
    totalCents: 23500,
    history: const [
      (OrderStatus.created, -3100),
      (OrderStatus.assigned, -3096),
      (OrderStatus.pickedUp, -3085),
      (OrderStatus.inTransit, -3080),
      (OrderStatus.delivered, -3062),
    ],
  );
  return (orders: orders, events: events);
}
