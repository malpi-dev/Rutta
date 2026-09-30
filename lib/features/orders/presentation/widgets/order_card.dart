import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/presentation/formatters.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/presentation/widgets/status_chip.dart';

class OrderCard extends ConsumerWidget {
  const OrderCard({
    required this.order,
    this.onTap,
    this.showCustomer = false,
    super.key,
  });

  final Order order;
  final VoidCallback? onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final now = ref.watch(clockProvider).nowUtc();
    final customer = order.customerName;
    return Semantics(
      identifier: 'order-card-${order.code}',
      child: Card(
        key: Key('order-card-${order.code}'),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.code,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    OrderStatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  order.pickup.name ?? order.pickup.address,
                  style: theme.textTheme.bodyMedium,
                ),
                if (showCustomer && customer != null)
                  Text(
                    customer,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatOrderDate(order.createdAt, now),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                    Text(
                      formatMoneyCents(order.totalCents),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
