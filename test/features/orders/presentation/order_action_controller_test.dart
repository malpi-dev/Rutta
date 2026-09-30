import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/orders/domain/available_order_actions.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/orders_repository.dart';
import 'package:rutta/features/orders/presentation/order_action_controller.dart';

import '../../../helpers/builders.dart';

class _MockOrdersRepository extends Mock implements OrdersRepository {}

void main() {
  setUpAll(() => registerFallbackValue(OrderStatus.pickedUp));

  ProviderContainer makeContainer(OrdersRepository repo) {
    final container = ProviderContainer(
      retry: noAutomaticRetry,
      overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('run(pickUp) advances to picked_up and ends in AsyncData', () async {
    final repo = _MockOrdersRepository();
    when(
      () => repo.advanceStatus('o1', OrderStatus.pickedUp),
    ).thenAnswer((_) async => buildOrder(status: OrderStatus.pickedUp));
    final container = makeContainer(repo);
    final provider = orderActionControllerProvider('o1');
    container.listen(provider, (_, _) {});

    await container.read(provider.notifier).run(OrderAction.pickUp);

    verify(() => repo.advanceStatus('o1', OrderStatus.pickedUp)).called(1);
    expect(container.read(provider), isA<AsyncData<void>>());
  });

  test('a CourierBusyError stays in the state as AsyncError', () async {
    final repo = _MockOrdersRepository();
    when(
      () => repo.advanceStatus(any(), any()),
    ).thenThrow(const CourierBusyError());
    final container = makeContainer(repo);
    final provider = orderActionControllerProvider('o1');
    container.listen(provider, (_, _) {});

    await container.read(provider.notifier).run(OrderAction.pickUp);

    final state = container.read(provider);
    expect(state, isA<AsyncError<void>>());
    expect(state.error, isA<CourierBusyError>());
  });
}
