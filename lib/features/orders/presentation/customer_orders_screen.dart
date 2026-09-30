import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/presentation/async_state_view.dart';
import 'package:rutta/core/presentation/empty_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';

/// Provisional list; phase 06 replaces it.
class CustomerOrdersScreen extends ConsumerWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: AsyncStateView(
        value: ref.watch(myOrdersProvider),
        onRetry: () => ref.invalidate(myOrdersProvider),
        isEmpty: (orders) => orders.isEmpty,
        empty: EmptyState(
          icon: Icons.inbox_outlined,
          title: l10n.ordersEmptyTitle,
        ),
        data: (orders) => ListView(
          children: [
            for (final order in orders)
              ListTile(
                key: Key('order-${order.code}'),
                title: Text(order.code),
                subtitle: Text(order.status.wireName),
              ),
          ],
        ),
      ),
    );
  }
}
