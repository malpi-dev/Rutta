import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/presentation/root_scaffold_messenger.dart';
import 'package:rutta/features/orders/domain/available_order_actions.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/presentation/order_action_controller.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/l10n/app_localizations.dart';

/// Primary contextual action of the courier detail (pick up, start, deliver).
class CourierActionButton extends ConsumerWidget {
  const CourierActionButton({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final orders = ref.watch(myOrdersProvider).value ?? const <Order>[];
    final state = ref.watch(availableOrderActionsProvider)(
      role: UserRole.courier,
      status: order.status,
      hasOtherOrderInProgress: hasOtherOrderInProgress(orders, order.id),
    );
    if (state == null) return const SizedBox.shrink();

    // Errors are shown once, from here, so they outlive rebuilds.
    ref.listen(orderActionControllerProvider(order.id), (previous, next) {
      if (next case AsyncError(:final error)) showErrorSnackBar(error, l10n);
    });
    final isLoading = ref
        .watch(orderActionControllerProvider(order.id))
        .isLoading;
    final enabled = state.enabled && !isLoading;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: 'order-action-primary',
            child: FilledButton(
              key: const Key('order-action-primary'),
              onPressed: enabled
                  ? () => _onPressed(context, ref, state.action)
                  : null,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_label(state.action, l10n)),
            ),
          ),
          if (state.blockReason == ActionBlockReason.courierBusy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                key: const Key('order-action-blocked-hint'),
                l10n.errorCourierBusy,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onPressed(
    BuildContext context,
    WidgetRef ref,
    OrderAction action,
  ) async {
    final controller = ref.read(
      orderActionControllerProvider(order.id).notifier,
    );
    if (action == OrderAction.markDelivered) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmDeliveredDialog(code: order.code),
      );
      if (confirmed != true) return;
    }
    await controller.run(action);
  }

  static String _label(OrderAction action, AppLocalizations l10n) =>
      switch (action) {
        OrderAction.pickUp => l10n.actionPickUp,
        OrderAction.startDelivery => l10n.actionStartDelivery,
        OrderAction.markDelivered => l10n.actionMarkDelivered,
      };
}

class _ConfirmDeliveredDialog extends StatelessWidget {
  const _ConfirmDeliveredDialog({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.confirmDeliveredTitle),
      content: Text(l10n.confirmDeliveredBody(code)),
      actions: [
        TextButton(
          key: const Key('cancel-delivered'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        Semantics(
          identifier: 'confirm-delivered',
          child: FilledButton(
            key: const Key('confirm-delivered'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirm),
          ),
        ),
      ],
    );
  }
}
