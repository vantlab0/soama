import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/soama_radii.dart';
import '../design_system/soama_typography.dart';
import 'soama_colors.dart';

/// Configures light and dark ThemeData for Soama with custom ThemeExtensions.
class SoamaTheme {
  SoamaTheme._();

  static ThemeData light() {
    const colors = SoamaThemeColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      cardColor: colors.surface,
      dividerColor: colors.border,
      primaryColor: colors.accent,
      colorScheme: ColorScheme.light(
        primary: colors.accent,
        onPrimary: colors.onAccent,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: SoamaRadii.radiusLg,
          side: BorderSide(color: Color(0x12111215), width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: _buildTextTheme(colors.textPrimary, colors.textSecondary),
      extensions: const [colors],
    );
  }

  static ThemeData dark() {
    const colors = SoamaThemeColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      cardColor: colors.surface,
      dividerColor: colors.border,
      primaryColor: colors.accent,
      colorScheme: ColorScheme.dark(
        primary: colors.accent,
        onPrimary: colors.onAccent,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: SoamaRadii.radiusLg,
          side: BorderSide(color: Color(0x1EFFFFFF), width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: _buildTextTheme(colors.textPrimary, colors.textSecondary),
      extensions: const [colors],
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: SoamaTypography.displayLarge.copyWith(color: primary),
      displayMedium: SoamaTypography.displayMedium.copyWith(color: primary),
      headlineLarge: SoamaTypography.headlineLarge.copyWith(color: primary),
      headlineMedium: SoamaTypography.headlineMedium.copyWith(color: primary),
      headlineSmall: SoamaTypography.headlineSmall.copyWith(color: primary),
      titleLarge: SoamaTypography.titleLarge.copyWith(color: primary),
      titleMedium: SoamaTypography.titleMedium.copyWith(color: primary),
      bodyLarge: SoamaTypography.bodyLarge.copyWith(color: primary),
      bodyMedium: SoamaTypography.bodyMedium.copyWith(color: secondary),
      bodySmall: SoamaTypography.bodySmall.copyWith(color: secondary),
      labelLarge: SoamaTypography.labelLarge.copyWith(color: primary),
      labelMedium: SoamaTypography.labelMedium.copyWith(color: secondary),
      labelSmall: SoamaTypography.labelSmall.copyWith(color: secondary),
    );
  }
}
