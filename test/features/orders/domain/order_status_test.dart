import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

void main() {
  const allowed = {
    (OrderStatus.created, OrderStatus.assigned),
    (OrderStatus.created, OrderStatus.cancelled),
    (OrderStatus.assigned, OrderStatus.pickedUp),
    (OrderStatus.assigned, OrderStatus.cancelled),
    (OrderStatus.pickedUp, OrderStatus.inTransit),
    (OrderStatus.inTransit, OrderStatus.delivered),
  };

  group('canTransitionTo', () {
    for (final from in OrderStatus.values) {
      for (final to in OrderStatus.values) {
        final expected = allowed.contains((from, to));
        test('$from -> $to is $expected', () {
          expect(from.canTransitionTo(to), expected);
        });
      }
    }
  });

  test('flags', () {
    const expected = {
      // status: (isActive, isInProgress, isTerminal)
      OrderStatus.created: (true, false, false),
      OrderStatus.assigned: (true, false, false),
      OrderStatus.pickedUp: (true, true, false),
      OrderStatus.inTransit: (true, true, false),
      OrderStatus.delivered: (false, false, true),
      OrderStatus.cancelled: (false, false, true),
    };
    for (final s in OrderStatus.values) {
      expect(
        (s.isActive, s.isInProgress, s.isTerminal),
        expected[s],
        reason: '$s',
      );
    }
  });

  test('wire names round-trip', () {
    for (final s in OrderStatus.values) {
      expect(OrderStatus.fromWire(s.wireName), s);
    }
    expect(OrderStatus.pickedUp.wireName, 'picked_up');
    expect(OrderStatus.inTransit.wireName, 'in_transit');
  });

  test('unknown wire value throws', () {
    expect(() => OrderStatus.fromWire('teleported'), throwsFormatException);
  });
}
