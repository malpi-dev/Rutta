import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/theme/app_colors.dart';
import 'package:rutta/core/theme/rutta_colors.dart';

/// Drop-shaped pin. Use it with `Alignment.topCenter` so the tip touches the
/// point.
class PlacePin extends StatelessWidget {
  const PlacePin({
    required this.icon,
    required this.color,
    required this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(Icons.location_on, size: 44, color: color),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(icon, size: 14, color: AppColors.markerContent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pickup pin (storefront icon).
class PickupPin extends StatelessWidget {
  const PickupPin({super.key});

  @override
  Widget build(BuildContext context) => PlacePin(
    icon: Icons.storefront,
    color: context.colors.pickupMarker,
    semanticLabel: context.l10n.pickupPinLabel,
  );
}

/// Drop-off pin (home icon).
class DropoffPin extends StatelessWidget {
  const DropoffPin({super.key});

  @override
  Widget build(BuildContext context) => PlacePin(
    icon: Icons.home,
    color: context.colors.dropoffMarker,
    semanticLabel: context.l10n.dropoffPinLabel,
  );
}

/// Courier marker: a circle with a navigation arrow rotated to the heading.
class CourierPin extends StatelessWidget {
  const CourierPin({
    required this.headingDegrees,
    required this.stale,
    super.key,
  });

  final double headingDegrees;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: context.l10n.courierPinLabel,
      child: ExcludeSemantics(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: stale ? colors.courierStale : colors.courierMarker,
            border: Border.all(color: AppColors.markerContent, width: 3),
            boxShadow: const [
              BoxShadow(
                color: AppColors.markerShadow,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Transform.rotate(
            angle: headingDegrees * math.pi / 180,
            child: const Icon(
              Icons.navigation,
              size: 18,
              color: AppColors.markerContent,
            ),
          ),
        ),
      ),
    );
  }
}
