import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';

/// Clean container component with crisp borders and no ambient haze or glowing shadows.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final List<BoxShadow>? shadows;
  final bool enableSpecular;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(SoamaSpacing.md),
    this.margin,
    this.borderRadius = SoamaRadii.radiusXl,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.blurSigma = 0.0,
    this.shadows = const [],
    this.enableSpecular = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    final effectiveBg = backgroundColor ??
        (isDark ? const Color(0xFF1E2129) : colors.surfaceSecondary);
    final effectiveBorder = borderColor ?? colors.border;
    final effectiveShadows = shadows ?? const [];

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
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
