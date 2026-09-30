import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/theme/rutta_colors.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';

/// Warning strip shown while the live connection is down. Loading and error
/// states of the monitor render nothing (they must never break the screen).
class ReconnectingBanner extends ConsumerWidget {
  const ReconnectingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(isConnectedProvider).value;
    if (connected != false) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      key: const Key('reconnecting-banner'),
      width: double.infinity,
      color: colors.warning,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.reconnecting,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
