import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/presentation/async_state_view.dart';
import 'package:rutta/core/presentation/empty_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/presentation/skeleton.dart';
import 'package:rutta/core/router/routes.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/orders/presentation/widgets/order_card.dart';
import 'package:rutta/features/orders/presentation/widgets/reconnecting_banner.dart';
import 'package:rutta/features/orders/presentation/widgets/section_header.dart';

/// Customer home: their orders split into Active and History, updated live.
class CustomerOrdersScreen extends ConsumerWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDemo = ref.watch(appModeControllerProvider) is AppModeDemo;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myOrdersTitle),
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
                          icon: Icons.receipt_long_outlined,
                          title: l10n.ordersEmptyTitle,
                          message: isDemo
                              ? l10n.noOrdersDemoHint
                              : l10n.noOrdersLiveHint,
                        ),
                      ),
                    ],
                  ),
                ),
                data: (orders) => _OrdersList(orders: orders),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = orders.where((o) => o.status.isActive).toList();
    final history = orders.where((o) => !o.status.isActive).toList();
    Widget card(Order o) => OrderCard(
      order: o,
      onTap: () => context.push(Routes.customerOrder(o.id)),
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (active.isNotEmpty) ...[
          SectionHeader(title: l10n.activeSection),
          ...active.map(card),
        ],
        if (history.isNotEmpty) ...[
          SectionHeader(title: l10n.historySection),
          ...history.map(card),
        ],
      ],
    );
  }
}
