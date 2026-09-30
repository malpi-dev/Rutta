import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/theme/rutta_colors.dart';
import 'package:rutta/features/location_permission/presentation/location_permission_sheet.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';
import 'package:rutta/features/tracking/presentation/location_publisher.dart';
import 'package:rutta/features/tracking/presentation/location_publisher_engine.dart';

/// Courier's "Sharing location" status under the primary action.
class SharingIndicator extends ConsumerWidget {
  const SharingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(locationSharingStateProvider).value ??
        const LocationSharingState();
    if (state.status == SharingStatus.idle) return const SizedBox.shrink();
    final engine = ref.read(locationPublisherProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.colors;

    Widget dot(Color color) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    Widget action(String label, VoidCallback onPressed, {String id = ''}) =>
        Semantics(
          identifier: id,
          child: TextButton(
            key: id.isEmpty ? null : Key(id),
            onPressed: onPressed,
            child: Text(label),
          ),
        );

    final (
      Widget leading,
      String text,
      Widget? trailing,
    ) = switch (state.status) {
      SharingStatus.idle => (const SizedBox.shrink(), '', null),
      SharingStatus.waitingForFix => (
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        l10n.gettingLocation,
        null,
      ),
      SharingStatus.sharing => (
        dot(colors.success),
        l10n.sharingLocation,
        action(l10n.pause, engine.pause, id: 'sharing-toggle'),
      ),
      SharingStatus.paused => (
        dot(theme.colorScheme.outline),
        l10n.sharingPaused,
        action(
          l10n.resume,
          () => unawaited(engine.resume()),
          id: 'sharing-toggle',
        ),
      ),
      SharingStatus.blocked => (
        Icon(Icons.location_off, size: 18, color: colors.warning),
        switch (state.blockedBy) {
          LocationAccess.serviceDisabled => l10n.locationOffTitle,
          _ => l10n.locationOffCustomerCantSee,
        },
        switch (state.blockedBy) {
          LocationAccess.deniedForever => action(
            l10n.openAppSettings,
            () => unawaited(
              ref.read(deviceLocationRepositoryProvider).openAppSettings(),
            ),
          ),
          LocationAccess.serviceDisabled => action(
            l10n.openLocationSettings,
            () => unawaited(
              ref.read(deviceLocationRepositoryProvider).openLocationSettings(),
            ),
          ),
          _ => action(
            l10n.enable,
            () => unawaited(_enable(context, ref, engine)),
          ),
        },
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        identifier: 'sharing-indicator',
        child: Row(
          key: const Key('sharing-indicator'),
          children: [
            leading,
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: state.status == SharingStatus.blocked
                      ? colors.warning
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _enable(
    BuildContext context,
    WidgetRef ref,
    LocationPublisherEngine engine,
  ) async {
    await ensureLocationAccess(context, ref);
    await engine.retryAccess();
  }
}
