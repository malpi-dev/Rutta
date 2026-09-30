import 'package:flutter/material.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/theme/rutta_colors.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/presentation/widgets/status_labels.dart';

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.colors;
    final color = switch (status) {
      OrderStatus.created || OrderStatus.cancelled => colors.neutral,
      OrderStatus.assigned => scheme.secondary,
      OrderStatus.pickedUp || OrderStatus.inTransit => scheme.primary,
      OrderStatus.delivered => colors.success,
    };
    final label = statusLabel(status, context.l10n);
    return Semantics(
      label: context.l10n.statusSemantics(label),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
