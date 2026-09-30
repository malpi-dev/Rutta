import 'package:flutter/material.dart';
import 'package:rutta/core/theme/app_colors.dart';
import 'package:rutta/core/theme/rutta_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final onPrimary = isDark
        ? AppColors.onPrimaryDark
        : AppColors.onPrimaryLight;
    final secondary = isDark
        ? AppColors.secondaryDark
        : AppColors.secondaryLight;
    final background = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final onSurface = isDark
        ? AppColors.onSurfaceDark
        : AppColors.onSurfaceLight;
    final error = isDark ? AppColors.errorDark : AppColors.errorLight;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryLight,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: secondary,
          surface: surface,
          onSurface: onSurface,
          error: error,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: _textTheme(brightness, onSurface),
      extensions: [if (isDark) RuttaColors.dark() else RuttaColors.light()],
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Bold 14 sp counts as "large text" (3:1 minimum contrast), which the
      // brand orange reaches against white; regular weight would need 4.5:1.
      // Secondary (navy / light blue) instead of the orange primary for
      // low-emphasis buttons: orange text on the light background is < 3:1.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: _buttonLabel.resolve({}),
          foregroundColor: secondary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: _buttonLabel.resolve({}),
          foregroundColor: secondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: _buttonLabel.resolve({}),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static const _buttonLabel = WidgetStatePropertyAll<TextStyle>(
    TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700),
  );

  static TextTheme _textTheme(Brightness brightness, Color onSurface) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    TextStyle? heading(TextStyle? s, FontWeight w) =>
        s?.copyWith(fontFamily: 'Manrope', fontWeight: w);
    TextStyle? body(TextStyle? s) => s?.copyWith(fontFamily: 'Inter');

    return TextTheme(
      displayLarge: heading(base.displayLarge, FontWeight.w800),
      displayMedium: heading(base.displayMedium, FontWeight.w800),
      displaySmall: heading(base.displaySmall, FontWeight.w800),
      headlineLarge: heading(base.headlineLarge, FontWeight.w700),
      headlineMedium: heading(base.headlineMedium, FontWeight.w700),
      headlineSmall: heading(base.headlineSmall, FontWeight.w700),
      titleLarge: heading(base.titleLarge, FontWeight.w600),
      titleMedium: heading(base.titleMedium, FontWeight.w600),
      titleSmall: heading(base.titleSmall, FontWeight.w600),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall),
    ).apply(bodyColor: onSurface, displayColor: onSurface);
  }
}
