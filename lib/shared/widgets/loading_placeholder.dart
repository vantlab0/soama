import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';

enum SkeletonShape {
  rounded,
  circle,
  pill,
}

class LoadingPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final SkeletonShape shape;
  final EdgeInsetsGeometry? margin;

  const LoadingPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = SkeletonShape.rounded,
    this.margin,
  });

  const LoadingPlaceholder.card({
    super.key,
    this.width = double.infinity,
    this.height = 110.0,
    this.margin = const EdgeInsets.only(bottom: 12.0),
  })  : shape = SkeletonShape.rounded,
        borderRadius = SoamaRadii.radiusXl;

  const LoadingPlaceholder.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        shape = SkeletonShape.circle,
        borderRadius = null;

  const LoadingPlaceholder.line({
    super.key,
    this.width = double.infinity,
    this.height = 14.0,
    this.margin,
  })  : shape = SkeletonShape.pill,
        borderRadius = SoamaRadii.radiusPill;

  @override
  State<LoadingPlaceholder> createState() => _LoadingPlaceholderState();
}

class _LoadingPlaceholderState extends State<LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final isReducedMotion = SoamaMotion.isReducedMotion(context);

    final BorderRadius effectiveRadius = switch (widget.shape) {
      SkeletonShape.circle => BorderRadius.circular(9999),
      SkeletonShape.pill => SoamaRadii.radiusPill,
      SkeletonShape.rounded => widget.borderRadius ?? SoamaRadii.radiusMd,
    };

    final baseColor = isDark
        ? const Color(0xFF20232C)
        : const Color(0xFFE9E5DC);

    if (isReducedMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: baseColor.withOpacity(0.5),
          borderRadius: effectiveRadius,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: baseColor.withOpacity(_pulseAnimation.value),
            borderRadius: effectiveRadius,
            border: Border.all(
              color: colors.border.withOpacity(0.3),
              width: 0.8,
            ),
          ),
        );
      },
    );
  }
}
