import 'package:flutter/material.dart';

/// Semantic colors for Soama design system.
/// Implemented as a ThemeExtension to support flawless light/dark mode interpolation.
class SoamaThemeColors extends ThemeExtension<SoamaThemeColors> {
  final Color canvas;
  final Color surface;
  final Color surfaceSecondary;
  Color get surfaceSubtle => surfaceSecondary;
  final Color glassSurface;
  final Color glassSurfaceSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color glassBorder;
  final Color accent;
  final Color accentHover;
  final Color accentMuted;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color error;
  final Color starGold;

  const SoamaThemeColors({
    required this.canvas,
    required this.surface,
    required this.surfaceSecondary,
    required this.glassSurface,
    required this.glassSurfaceSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.glassBorder,
    required this.accent,
    required this.accentHover,
    required this.accentMuted,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.error,
    required this.starGold,
  });

  // Warm Ivory Light Mode Palette
  static const light = SoamaThemeColors(
    canvas: Color(0xFFFBF9F5),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF3EFE7),
    glassSurface: Color(0xB8FFFFFF),
    glassSurfaceSecondary: Color(0x99F5F3ED),
    textPrimary: Color(0xFF111215),
    textSecondary: Color(0xFF5F6370),
    textTertiary: Color(0xFF8F94A2),
    border: Color(0x14111215),
    glassBorder: Color(0x38FFFFFF),
    accent: Color(0xFFC7E81A), // Restrained luxury chartreuse
    accentHover: Color(0xFFD4F024),
    accentMuted: Color(0x28C7E81A),
    onAccent: Color(0xFF111215), // Deep near-black for crisp contrast
    success: Color(0xFF2E7D32),
    warning: Color(0xFFED6C02),
    error: Color(0xFFD32F2F),
    starGold: Color(0xFFFFB800),
  );

  // Deep Charcoal Dark Mode Palette
  static const dark = SoamaThemeColors(
    canvas: Color(0xFF0D0E12),
    surface: Color(0xFF16181D),
    surfaceSecondary: Color(0xFF1E2129),
    glassSurface: Color(0xB81A1C24),
    glassSurfaceSecondary: Color(0x80232631),
    textPrimary: Color(0xFFF5F6F8),
    textSecondary: Color(0xFF9EA3B2),
    textTertiary: Color(0xFF64697B),
    border: Color(0x1FFFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    accent: Color(0xFFD4F024), // Vibrant chartreuse in dark mode
    accentHover: Color(0xFFE2FA3A),
    accentMuted: Color(0x33D4F024),
    onAccent: Color(0xFF111215),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFF9800),
    error: Color(0xFFEF5350),
    starGold: Color(0xFFFFC107),
  );

  @override
  SoamaThemeColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceSecondary,
    Color? glassSurface,
    Color? glassSurfaceSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? glassBorder,
    Color? accent,
    Color? accentHover,
    Color? accentMuted,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? error,
    Color? starGold,
  }) {
    return SoamaThemeColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      glassSurface: glassSurface ?? this.glassSurface,
      glassSurfaceSecondary: glassSurfaceSecondary ?? this.glassSurfaceSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      glassBorder: glassBorder ?? this.glassBorder,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentMuted: accentMuted ?? this.accentMuted,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      starGold: starGold ?? this.starGold,
    );
  }

  @override
  SoamaThemeColors lerp(ThemeExtension<SoamaThemeColors>? other, double t) {
    if (other is! SoamaThemeColors) return this;
    return SoamaThemeColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassSurfaceSecondary: Color.lerp(glassSurfaceSecondary, other.glassSurfaceSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      starGold: Color.lerp(starGold, other.starGold, t)!,
    );
  }
}

/// Convenience extension for cleaner access in widgets: `context.soamaColors`
extension SoamaThemeContext on BuildContext {
  SoamaThemeColors get soamaColors {
    return Theme.of(this).extension<SoamaThemeColors>() ??
        (Theme.of(this).brightness == Brightness.dark
            ? SoamaThemeColors.dark
            : SoamaThemeColors.light);
  }

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// Compatibility alias for SoamaThemeColors
typedef SoamaColors = SoamaThemeColors;
