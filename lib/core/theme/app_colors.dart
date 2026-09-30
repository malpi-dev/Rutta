import 'dart:ui';

/// Design tokens (definition section 11). The only place where raw colors are
/// allowed.
abstract final class AppColors {
  static const primaryLight = Color(0xFFFF5A1F);
  static const primaryDark = Color(0xFFFF7A45);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const onPrimaryDark = Color(0xFF1A0E08);
  static const secondaryLight = Color(0xFF1E3A5F);
  static const secondaryDark = Color(0xFF8FB3E0);
  static const successLight = Color(0xFF1F9D55);
  static const successDark = Color(0xFF4ADE80);
  static const warningLight = Color(0xFFD97706);
  static const warningDark = Color(0xFFFBBF24);
  static const errorLight = Color(0xFFDC2626);
  static const errorDark = Color(0xFFF87171);
  static const backgroundLight = Color(0xFFF7F7F5);
  static const backgroundDark = Color(0xFF0F141A);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1A212B);
  static const onSurfaceLight = Color(0xFF1B1F24);
  static const onSurfaceDark = Color(0xFFE6EAF0);

  /// `created` / `cancelled` statuses and the stale courier marker.
  static const neutralLight = Color(0xFF6B7280);
  static const neutralDark = Color(0xFF9CA3AF);
}
