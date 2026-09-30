import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/features/orders/domain/available_order_actions.dart';

part 'order_action_controller.g.dart';

/// Runs the courier's primary action on one order. Errors stay in the state
/// (`AsyncError`) for the UI to show; the order itself updates through its
/// stream.
@riverpod
class OrderActionController extends _$OrderActionController {
  @override
  FutureOr<void> build(String orderId) {}

  /// Moves the order to [action]'s target status.
  Future<void> run(OrderAction action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(ordersRepositoryProvider)
          .advanceStatus(orderId, action.target),
    );
  }
}
