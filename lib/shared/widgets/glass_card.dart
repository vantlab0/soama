import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/design_system.dart';
import 'glass_surface.dart';

/// Interactive Apple-inspired card with subtle spring physics on press.
/// By default, uses high-performance surface rendering (zero-blur rasterizer overhead)
/// while supporting full blur when [enableBlur] is explicitly set to true.
class GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool enableBlur;
  final GlassBlurIntensity blurIntensity;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = SoamaSpacing.cardPadding,
    this.margin,
    this.borderRadius = SoamaRadii.radiusLg,
    this.backgroundColor,
    this.borderColor,
    this.enableBlur = false,
    this.blurIntensity = GlassBlurIntensity.standard,
    this.shadows,
  });

  const GlassCard.floating({
    super.key,
    required this.child,
    this.onTap,
    this.padding = SoamaSpacing.cardPadding,
    this.margin,
    this.borderRadius = SoamaRadii.radiusLg,
    this.backgroundColor,
    this.borderColor,
    this.blurIntensity = GlassBlurIntensity.standard,
    this.shadows,
  }) : enableBlur = true;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = SoamaMotion.isReducedMotion(context);
    final targetScale = _isPressed && !isReducedMotion ? 0.98 : 1.0;

    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: targetScale,
          duration: SoamaMotion.fast,
          curve: SoamaMotion.easeOutSpring,
          child: GlassSurface(
            padding: widget.padding,
            margin: widget.margin,
            borderRadius: widget.borderRadius,
            backgroundColor: widget.backgroundColor,
            borderColor: widget.borderColor,
            blurIntensity: widget.enableBlur ? widget.blurIntensity : GlassBlurIntensity.none,
            shadows: widget.shadows,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
