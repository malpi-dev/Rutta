import 'dart:async';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_fixtures.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/data/demo_courier_simulator.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';

/// In-memory world shared by every mock repository, so a change made through
/// one of them shows up in the others (like Realtime does with Supabase).
class DemoStore {
  DemoStore.seeded({
    required this.role,
    required this.clock,

    /// Simulated read latency (tests: [Duration.zero]).
    this.latency = const Duration(milliseconds: 450),
    this.simulationDuration = const Duration(seconds: 60),
    this.simulationTick = const Duration(seconds: 1),
  }) {
    final world = buildDemoWorld(clock.nowUtc());
    for (final order in world.orders) {
      _orders[order.id] = order;
    }
    _events.addAll(world.events);
  }

  /// Empty store used while the app is live: no data, no timers.
  DemoStore.idle({
    required this.clock,
    this.role = UserRole.customer,
    this.latency = Duration.zero,
    this.simulationDuration = const Duration(seconds: 60),
    this.simulationTick = const Duration(seconds: 1),
  });

  final UserRole role;
  final Clock clock;
  final Duration latency;
  final Duration simulationDuration;
  final Duration simulationTick;

  final _orders = <String, Order>{};
  final _events = <OrderStatusEvent>[];
  final _locations = <String, CourierLocation>{};
  final _simulations = <String, StreamSubscription<Object?>>{};
  final _changes = StreamController<void>.broadcast();
  var _disposed = false;

  String get currentUserId =>
      role == UserRole.customer ? DemoUsers.customerId : DemoUsers.courierId;

  /// Broadcast; fires after every mutation.
  Stream<void> get changes => _changes.stream;

  /// Customer: `customerId == me`. Courier: `courierId == me`. Newest first.
  List<Order> ordersForCurrentUser() {
    final mine = _orders.values.where(
      (o) => role == UserRole.customer
          ? o.customerId == currentUserId
          : o.courierId == currentUserId,
    );
    return mine.sortedBy((o) => o.createdAt).reversed.toList();
  }

  Order? order(String id) => _orders[id];

  /// Ascending by creation time.
  List<OrderStatusEvent> events(String orderId) =>
      _events.where((e) => e.orderId == orderId).sortedBy((e) => e.createdAt);

  CourierLocation? location(String orderId) => _locations[orderId];

  /// Adds an order (used by tests to build special situations).
  @visibleForTesting
  void addOrder(Order order) {
    _orders[order.id] = order;
    _notify();
  }

  /// Applies the same business rules as `rutta.advance_order_status` and adds
  /// the status event.
  Order advance(
    String orderId,
    OrderStatus next, {
    required String actorId,
    bool asSystem = false,
  }) {
    final order = _orders[orderId];
    if (order == null) throw NotFoundError('order', orderId);
    final invalid = InvalidTransitionError(
      from: order.status.wireName,
      to: next.wireName,
    );
    if (!asSystem) {
      if (order.courierId != actorId) throw const NotAssignedToYouError();
      const courierTransitions = {
        (OrderStatus.assigned, OrderStatus.pickedUp),
        (OrderStatus.pickedUp, OrderStatus.inTransit),
        (OrderStatus.inTransit, OrderStatus.delivered),
      };
      if (!courierTransitions.contains((order.status, next))) throw invalid;
    } else if (!order.status.canTransitionTo(next)) {
      throw invalid;
    }
    final courierId = order.courierId;
    if (next.isInProgress &&
        courierId != null &&
        _orders.values.any(
          (o) =>
              o.id != orderId &&
              o.courierId == courierId &&
              o.status.isInProgress,
        )) {
      throw const CourierBusyError();
    }
    final now = clock.nowUtc();
    final updated = order.copyWith(status: next, updatedAt: now);
    _orders[orderId] = updated;
    _events.add(
      OrderStatusEvent(
        id: _events.length + 1,
        orderId: orderId,
        status: next,
        createdAt: now,
      ),
    );
    if (next.isTerminal) _locations.remove(orderId);
    _notify();
    return updated;
  }

  void setLocation(String orderId, CourierLocation? location) {
    if (location == null) {
      _locations.remove(orderId);
    } else {
      _locations[orderId] = location;
    }
    _notify();
  }

  /// Starts (once) the simulation of a courier that is NOT the current user
  /// (RT-1042 when exploring as customer).
  void ensureCustomerSimulation(String orderId) {
    final order = _orders[orderId];
    final courierId = order?.courierId;
    if (order == null ||
        courierId == null ||
        courierId == currentUserId ||
        _simulations.containsKey(orderId)) {
      return;
    }
    if (order.status == OrderStatus.pickedUp) {
      setLocation(
        orderId,
        CourierLocation(
          courierId: courierId,
          orderId: orderId,
          point: order.pickup.point,
          recordedAt: clock.nowUtc(),
        ),
      );
      return;
    }
    if (order.status != OrderStatus.inTransit) return;
    final simulator = DemoCourierSimulator(
      route: order.route,
      clock: clock,
      targetDuration: simulationDuration,
      tick: simulationTick,
      startFraction: 0.15,
    );
    _simulations[orderId] = simulator.positions().listen(
      (p) => setLocation(
        orderId,
        CourierLocation(
          courierId: courierId,
          orderId: orderId,
          point: p.point,
          recordedAt: p.timestamp,
          heading: p.heading,
          speedMps: p.speedMps,
        ),
      ),
      onDone: () {
        if (_disposed) return;
        advance(
          orderId,
          OrderStatus.delivered,
          actorId: courierId,
          asSystem: true,
        );
      },
    );
  }

  void dispose() {
    _disposed = true;
    for (final sub in _simulations.values) {
      unawaited(sub.cancel());
    }
    _simulations.clear();
    unawaited(_changes.close());
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }
}
