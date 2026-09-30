import 'package:flutter/material.dart';
import 'package:rutta/core/theme/app_colors.dart';

@immutable
class RuttaColors extends ThemeExtension<RuttaColors> {
  const RuttaColors({
    required this.success,
    required this.warning,
    required this.neutral,
    required this.routeRemaining,
    required this.routeTraveled,
    required this.pickupMarker,
    required this.dropoffMarker,
    required this.courierMarker,
    required this.courierStale,
  });

  factory RuttaColors.light() => RuttaColors._from(
    primary: AppColors.primaryLight,
    secondary: AppColors.secondaryLight,
    success: AppColors.successLight,
    warning: AppColors.warningLight,
    neutral: AppColors.neutralLight,
  );

  factory RuttaColors.dark() => RuttaColors._from(
    primary: AppColors.primaryDark,
    secondary: AppColors.secondaryDark,
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    neutral: AppColors.neutralDark,
  );

  factory RuttaColors._from({
    required Color primary,
    required Color secondary,
    required Color success,
    required Color warning,
    required Color neutral,
  }) => RuttaColors(
    success: success,
    warning: warning,
    neutral: neutral,
    routeRemaining: primary,
    routeTraveled: primary.withValues(alpha: 0.35),
    pickupMarker: secondary,
    dropoffMarker: secondary,
    courierMarker: primary,
    courierStale: neutral,
  );

  final Color success;
  final Color warning;
  final Color neutral;
  final Color routeRemaining;
  final Color routeTraveled;
  final Color pickupMarker;
  final Color dropoffMarker;
  final Color courierMarker;
  final Color courierStale;

  @override
  RuttaColors copyWith({
    Color? success,
    Color? warning,
    Color? neutral,
    Color? routeRemaining,
    Color? routeTraveled,
    Color? pickupMarker,
    Color? dropoffMarker,
    Color? courierMarker,
    Color? courierStale,
  }) => RuttaColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    neutral: neutral ?? this.neutral,
    routeRemaining: routeRemaining ?? this.routeRemaining,
    routeTraveled: routeTraveled ?? this.routeTraveled,
    pickupMarker: pickupMarker ?? this.pickupMarker,
    dropoffMarker: dropoffMarker ?? this.dropoffMarker,
    courierMarker: courierMarker ?? this.courierMarker,
    courierStale: courierStale ?? this.courierStale,
  );

  @override
  RuttaColors lerp(ThemeExtension<RuttaColors>? other, double t) {
    if (other is! RuttaColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return RuttaColors(
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      neutral: mix(neutral, other.neutral),
      routeRemaining: mix(routeRemaining, other.routeRemaining),
      routeTraveled: mix(routeTraveled, other.routeTraveled),
      pickupMarker: mix(pickupMarker, other.pickupMarker),
      dropoffMarker: mix(dropoffMarker, other.dropoffMarker),
      courierMarker: mix(courierMarker, other.courierMarker),
      courierStale: mix(courierStale, other.courierStale),
    );
  }
}

extension RuttaColorsX on BuildContext {
  RuttaColors get colors => Theme.of(this).extension<RuttaColors>()!;
}
