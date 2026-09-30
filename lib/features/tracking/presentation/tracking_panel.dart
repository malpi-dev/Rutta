import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/presentation/async_state_view.dart';
import 'package:rutta/core/presentation/formatters.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/presentation/skeleton.dart';
import 'package:rutta/core/theme/rutta_colors.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/order_timeline.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/orders/presentation/widgets/courier_action_button.dart';
import 'package:rutta/features/orders/presentation/widgets/status_labels.dart';
import 'package:rutta/features/orders/presentation/widgets/status_timeline.dart';
import 'package:rutta/features/tracking/presentation/sharing_indicator.dart';
import 'package:rutta/features/tracking/presentation/tracking_providers.dart';

/// Bottom sheet content of the order detail (customer and courier variants).
class TrackingPanel extends StatelessWidget {
  const TrackingPanel({
    required this.order,
    required this.role,
    required this.scrollController,
    super.key,
  });

  final Order order;
  final UserRole role;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          OrderStatusHeadline(order: order, role: role),
          if (role == UserRole.courier) CourierActionButton(order: order),
          if (role == UserRole.courier && order.status.isInProgress)
            const SharingIndicator(),
          if (role == UserRole.customer && order.status.isInProgress)
            StaleLocationNotice(orderId: order.id),
          if (role == UserRole.customer && order.courierName != null) ...[
            const SizedBox(height: 20),
            _PersonRow(
              label: context.l10n.courierLabel,
              name: order.courierName!,
            ),
          ],
          if (role == UserRole.courier && order.customerName != null) ...[
            const SizedBox(height: 20),
            _PersonRow(
              label: context.l10n.customerLabel,
              name: order.customerName!,
            ),
          ],
          const SizedBox(height: 20),
          _Addresses(order: order),
          const SizedBox(height: 20),
          _Items(order: order),
          const SizedBox(height: 20),
          _Timeline(order: order),
        ],
      ),
    );
  }
}

/// Big status text plus a context line (ETA/distance, waiting hints...).
class OrderStatusHeadline extends ConsumerWidget {
  const OrderStatusHeadline({
    required this.order,
    this.role = UserRole.customer,
    super.key,
  });

  final Order order;
  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final contextLine = role == UserRole.courier
        ? _courierLine(context, ref, muted)
        : switch (order.status) {
            OrderStatus.created => Text(l10n.waitingForCourier, style: muted),
            OrderStatus.assigned => Text(
              l10n.trackingStartsOnPickup,
              style: muted,
            ),
            OrderStatus.pickedUp || OrderStatus.inTransit => _progressLine(
              context,
              ref,
              muted,
            ),
            OrderStatus.delivered => _deliveredLine(ref, muted),
            OrderStatus.cancelled => Text(l10n.orderCancelled, style: muted),
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          identifier: 'order-status-headline',
          child: Text(
            statusLabel(order.status, l10n),
            key: const Key('order-status-headline'),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 4),
        contextLine,
      ],
    );
  }

  Widget _courierLine(BuildContext context, WidgetRef ref, TextStyle? muted) {
    final l10n = context.l10n;
    return switch (order.status) {
      OrderStatus.assigned => Text(
        l10n.courierNextPickup(order.pickup.name ?? order.pickup.address),
        style: muted,
      ),
      OrderStatus.pickedUp => Text(l10n.courierNextStart, style: muted),
      // ETA and distance appear once the courier's own GPS fix arrives.
      OrderStatus.inTransit => _progressLine(
        context,
        ref,
        muted,
        fallback: l10n.courierHeadToDropoff,
      ),
      OrderStatus.delivered => _deliveredLine(ref, muted),
      OrderStatus.cancelled => Text(l10n.orderCancelled, style: muted),
      OrderStatus.created => Text(l10n.waitingForCourier, style: muted),
    };
  }

  Widget _progressLine(
    BuildContext context,
    WidgetRef ref,
    TextStyle? muted, {
    String? fallback,
  }) {
    final l10n = context.l10n;
    final progress = ref.watch(routeProgressProvider(order.id, role));
    if (progress == null) {
      return Text(fallback ?? l10n.waitingForLocation, style: muted);
    }
    final figures = muted?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Semantics(
          identifier: 'tracking-eta',
          child: Text(
            formatEta(progress.eta),
            key: const Key('tracking-eta'),
            style: figures?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(' · ', style: figures),
        Text(
          key: const Key('tracking-distance'),
          l10n.distanceLeft(formatDistance(progress.remainingMeters)),
          style: figures,
        ),
      ],
    );
  }

  Widget _deliveredLine(WidgetRef ref, TextStyle? muted) {
    final events = ref.watch(orderEventsProvider(order.id)).value;
    final delivered = events
        ?.where((e) => e.status == OrderStatus.delivered)
        .lastOrNull;
    return Builder(
      builder: (context) => Text(
        context.l10n.deliveredAt(
          formatTime(delivered?.createdAt ?? order.updatedAt),
        ),
        style: muted,
      ),
    );
  }
}

/// "Last updated 45 s ago". Only this small widget watches the ticking clock.
class StaleLocationNotice extends ConsumerWidget {
  const StaleLocationNotice({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isCourierLocationStaleProvider(orderId))) {
      return const SizedBox.shrink();
    }
    final location = ref.watch(courierLocationProvider(orderId)).value;
    if (location == null) return const SizedBox.shrink();
    final now =
        ref.watch(nowProvider).value ?? ref.watch(clockProvider).nowUtc();
    final warning = context.colors.warning;
    return Padding(
      key: const Key('stale-indicator'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: warning),
          const SizedBox(width: 6),
          Text(
            context.l10n.lastUpdatedAgo(
              formatAgo(now.difference(location.recordedAt)),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: warning),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
          child: Text(initials),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(name, style: theme.textTheme.titleSmall),
          ],
        ),
      ],
    );
  }
}

class _Addresses extends StatelessWidget {
  const _Addresses({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final pickupName = order.pickup.name;
    Widget line(IconData icon, String title, String subtitle) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ],
    );
    return Column(
      children: [
        line(
          Icons.storefront,
          pickupName ?? order.pickup.address,
          pickupName == null ? '' : order.pickup.address,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 11),
            child: SizedBox(
              height: 20,
              child: VerticalDivider(
                width: 2,
                thickness: 2,
                color: muted.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        line(Icons.home, context.l10n.dropoffLabel, order.dropoff.address),
      ],
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.itemsTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${item.quantity}× ${item.name}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(l10n.totalLabel, style: theme.textTheme.titleSmall),
            ),
            Text(
              formatMoneyCents(order.totalCents),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.timelineTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        AsyncStateView<List<OrderStatusEvent>>(
          value: ref.watch(orderEventsProvider(order.id)),
          loading: const Column(
            children: [
              SkeletonBox(height: 24),
              SizedBox(height: 12),
              SkeletonBox(height: 24),
              SizedBox(height: 12),
              SkeletonBox(height: 24),
            ],
          ),
          onRetry: () => ref.invalidate(orderEventsProvider(order.id)),
          data: (events) => StatusTimeline(
            steps: buildOrderTimeline(current: order.status, events: events),
          ),
        ),
      ],
    );
  }
}
