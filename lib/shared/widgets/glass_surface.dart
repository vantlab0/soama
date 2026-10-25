import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';

enum GlassBlurIntensity {
  none,
  subtle,
  standard,
  medium,
  heavy,
}

/// A clean, modern surface component without ambient glow or hazy blur.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final GlassBlurIntensity blurIntensity;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final bool enableSpecular;
  final bool forceFallback;

  const GlassSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = SoamaSpacing.cardPadding,
    this.margin,
    this.borderRadius = SoamaRadii.radiusLg,
    this.blurIntensity = GlassBlurIntensity.none,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.shadows = const [],
    this.enableSpecular = false,
    this.forceFallback = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    final Color effectiveBackground = backgroundColor ??
        (isDark ? const Color(0xFF16181D) : const Color(0xFFFFFFFF));

    final Color effectiveBorder = borderColor ?? colors.border;
    final List<BoxShadow> effectiveShadows = shadows ?? const [];

    // Clean UI: Render clean container with crisp border and background
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: borderRadius,
        border: Border.all(
          color: effectiveBorder,
          width: borderWidth,
        ),
        boxShadow: effectiveShadows,
      ),
      child: child,
    );
  }
}
