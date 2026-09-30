import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/theme/rutta_colors.dart';
import 'package:rutta/features/tracking/domain/device_location_repository.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

/// Checks access and, when missing, explains why before the system dialog
/// (F9). Returns the final access. Never blocks the caller's action: the
/// courier can keep working without sharing.
Future<LocationAccess> ensureLocationAccess(
  BuildContext context,
  WidgetRef ref,
) async {
  final repository = ref.read(deviceLocationRepositoryProvider);
  final LocationAccess access;
  try {
    access = await repository.checkAccess();
  } on DomainError {
    // Never block the courier's action because the GPS status is unknown.
    return LocationAccess.denied;
  }
  if (access == LocationAccess.granted || !context.mounted) return access;
  final result = await showModalBottomSheet<LocationAccess>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LocationPermissionSheet(
      repository: repository,
      initialAccess: access,
    ),
  );
  return result ?? access;
}

class _LocationPermissionSheet extends StatefulWidget {
  const _LocationPermissionSheet({
    required this.repository,
    required this.initialAccess,
  });

  final DeviceLocationRepository repository;
  final LocationAccess initialAccess;

  @override
  State<_LocationPermissionSheet> createState() =>
      _LocationPermissionSheetState();
}

class _LocationPermissionSheetState extends State<_LocationPermissionSheet> {
  late LocationAccess _access = widget.initialAccess;
  late final AppLifecycleListener _lifecycle;

  /// The sheet must pop once: both the system dialog result and the resume
  /// re-check can report `granted`.
  var _closed = false;

  @override
  void initState() {
    super.initState();
    // Back from the system settings: re-evaluate.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_recheck()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _recheck() async {
    final access = await widget.repository.checkAccess();
    _apply(access);
  }

  Future<void> _request() async {
    final access = await widget.repository.requestAccess();
    _apply(access);
  }

  void _apply(LocationAccess access) {
    if (!mounted || _closed) return;
    if (access == LocationAccess.granted) {
      _closed = true;
      Navigator.of(context).pop(LocationAccess.granted);
    } else {
      setState(() => _access = access);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (title, body, primaryLabel, primaryId, onPrimary) = switch (_access) {
      LocationAccess.deniedForever => (
        l10n.permissionBlockedTitle,
        l10n.permissionBlockedBody,
        l10n.openAppSettings,
        'permission-open-settings',
        () => unawaited(widget.repository.openAppSettings()),
      ),
      LocationAccess.serviceDisabled => (
        l10n.locationOffTitle,
        l10n.locationOffBody,
        l10n.openLocationSettings,
        'permission-open-location-settings',
        () => unawaited(widget.repository.openLocationSettings()),
      ),
      LocationAccess.denied || LocationAccess.granted => (
        l10n.permissionTitle,
        l10n.permissionBody,
        l10n.permissionContinue,
        'permission-continue',
        () => unawaited(_request()),
      ),
    };
    final blocked = _access != LocationAccess.denied;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              blocked ? Icons.location_off : Icons.location_on,
              size: 48,
              color: blocked
                  ? context.colors.warning
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              identifier: primaryId,
              child: FilledButton(
                key: Key(primaryId),
                onPressed: onPrimary,
                child: Text(primaryLabel),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'permission-not-now',
              child: TextButton(
                key: const Key('permission-not-now'),
                onPressed: () => Navigator.of(context).pop(_access),
                child: Text(l10n.notNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
