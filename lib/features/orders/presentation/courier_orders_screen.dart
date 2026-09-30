import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutta/core/presentation/async_state_view.dart';
import 'package:rutta/core/presentation/empty_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/presentation/skeleton.dart';
import 'package:rutta/core/router/routes.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/orders/presentation/widgets/order_card.dart';
import 'package:rutta/features/orders/presentation/widgets/reconnecting_banner.dart';
import 'package:rutta/features/orders/presentation/widgets/section_header.dart';

/// Courier home: assigned orders, in-progress ones first, updated live.
class CourierOrdersScreen extends ConsumerWidget {
  const CourierOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deliveriesTitle),
        actions: [
          Semantics(
            identifier: 'settings-open',
            child: IconButton(
              key: const Key('settings-open'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings,
              onPressed: () => context.push(Routes.settings),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const ReconnectingBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(myOrdersProvider.future),
              child: AsyncStateView<List<Order>>(
                value: ref.watch(myOrdersProvider),
                onRetry: () => ref.invalidate(myOrdersProvider),
                loading: const SkeletonList(),
                isEmpty: (orders) => orders.isEmpty,
                empty: LayoutBuilder(
                  builder: (context, constraints) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: constraints.maxHeight,
                        child: EmptyState(
                          icon: Icons.delivery_dining_outlined,
                          title: l10n.noDeliveriesTitle,
                          message: l10n.noDeliveriesHint,
                        ),
                      ),
                    ],
                  ),
                ),
                data: (orders) => _DeliveriesList(orders: orders),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveriesList extends StatelessWidget {
  const _DeliveriesList({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inProgress = orders.where((o) => o.status.isInProgress).toList();
    final assigned = orders
        .where((o) => o.status == OrderStatus.assigned)
        .toList();
    final completed = orders.where((o) => o.status.isTerminal).toList();
    Widget card(Order o) => OrderCard(
      order: o,
      showCustomer: true,
      onTap: () => context.push(Routes.courierOrder(o.id)),
    );
    Iterable<Widget> section(String title, List<Order> items) => [
      if (items.isNotEmpty) ...[
        SectionHeader(title: title),
        ...items.map(card),
      ],
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ...section(l10n.inProgressSection, inProgress),
        ...section(l10n.assignedSection, assigned),
        ...section(l10n.completedSection, completed),
      ],
    );
  }
}
