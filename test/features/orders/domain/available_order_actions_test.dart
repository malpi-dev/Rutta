import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/orders/domain/available_order_actions.dart';
import 'package:rutta/features/orders/domain/order_status.dart';

import '../../../helpers/builders.dart';

void main() {
  const actions = AvailableOrderActions();

  OrderActionState? courier(OrderStatus s, {bool busy = false}) => actions(
    role: UserRole.courier,
    status: s,
    hasOtherOrderInProgress: busy,
  );

  test('customer never has actions', () {
    for (final s in OrderStatus.values) {
      expect(
        actions(
          role: UserRole.customer,
          status: s,
          hasOtherOrderInProgress: false,
        ),
        isNull,
        reason: '$s',
      );
    }
  });

  test('courier: assigned -> enabled pickUp', () {
    final a = courier(OrderStatus.assigned)!;
    expect(a.action, OrderAction.pickUp);
    expect(a.enabled, isTrue);
    expect(a.action.target, OrderStatus.pickedUp);
  });

  test('courier: assigned while busy -> blocked pickUp', () {
    final a = courier(OrderStatus.assigned, busy: true)!;
    expect(a.action, OrderAction.pickUp);
    expect(a.blockReason, ActionBlockReason.courierBusy);
    expect(a.enabled, isFalse);
  });

  test('courier: pickedUp -> startDelivery, inTransit -> markDelivered', () {
    expect(courier(OrderStatus.pickedUp)!.action, OrderAction.startDelivery);
    expect(courier(OrderStatus.inTransit)!.action, OrderAction.markDelivered);
  });

  test('courier: no action for created/delivered/cancelled', () {
    expect(courier(OrderStatus.created), isNull);
    expect(courier(OrderStatus.delivered), isNull);
    expect(courier(OrderStatus.cancelled), isNull);
  });

  group('hasOtherOrderInProgress', () {
    test('another in-transit order counts', () {
      final orders = [
        buildOrder(id: 'a'),
        buildOrder(id: 'b', status: OrderStatus.inTransit),
      ];
      expect(hasOtherOrderInProgress(orders, 'a'), isTrue);
    });

    test('the current order does not count', () {
      final orders = [buildOrder(id: 'a', status: OrderStatus.inTransit)];
      expect(hasOtherOrderInProgress(orders, 'a'), isFalse);
    });

    test('assigned or delivered orders do not count', () {
      final orders = [
        buildOrder(id: 'a'),
        buildOrder(id: 'b'),
        buildOrder(id: 'c', status: OrderStatus.delivered),
      ];
      expect(hasOtherOrderInProgress(orders, 'a'), isFalse);
    });
  });
}
