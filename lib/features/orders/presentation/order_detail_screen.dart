import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/map/rutta_map.dart';
import 'package:rutta/core/presentation/async_state_view.dart';
import 'package:rutta/core/presentation/skeleton.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/orders/presentation/widgets/reconnecting_banner.dart';
import 'package:rutta/features/tracking/presentation/tracking_map.dart';
import 'package:rutta/features/tracking/presentation/tracking_panel.dart';

/// One screen with a variant per role. Phase 06 implements the customer
/// variant; the courier variant (phase 07) reuses the map, sections and
/// timeline.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    required this.orderId,
    required this.role,
    super.key,
  });

  final String orderId;
  final UserRole role;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _mapController = RuttaMapController();

  @override
  Widget build(BuildContext context) {
    final orderValue = ref.watch(orderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(orderValue.value?.code ?? '')),
      body: AsyncStateView(
        value: orderValue,
        loading: const OrderDetailSkeleton(),
        onRetry: () => ref.invalidate(orderProvider(widget.orderId)),
        data: (order) => Stack(
          children: [
            Positioned.fill(
              child: TrackingMap(
                order: order,
                role: widget.role,
                controller: _mapController,
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReconnectingBanner(),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.42,
              minChildSize: 0.22,
              maxChildSize: 0.88,
              builder: (context, scroll) => TrackingPanel(
                order: order,
                role: widget.role,
                scrollController: scroll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Map placeholder + panel skeleton while the order loads.
class OrderDetailSkeleton extends StatelessWidget {
  const OrderDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('order-detail-skeleton'),
      children: [
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const SizedBox.expand(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SkeletonBox(height: 28, width: 160),
              SizedBox(height: 12),
              SkeletonBox(height: 20),
              SizedBox(height: 12),
              SkeletonBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}
