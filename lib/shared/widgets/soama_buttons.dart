import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';
import 'glass_surface.dart';

enum ButtonSize {
  small,
  medium,
  large,
}

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonSize size;
  final bool isFullWidth;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = ButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      HapticFeedback.selectionClick();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isReducedMotion = SoamaMotion.isReducedMotion(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final double height = switch (widget.size) {
      ButtonSize.small => 36.0,
      ButtonSize.medium => 46.0,
      ButtonSize.large => 54.0,
    };

    final double horizontalPadding = switch (widget.size) {
      ButtonSize.small => 14.0,
      ButtonSize.medium => 20.0,
      ButtonSize.large => 26.0,
    };

    final TextStyle textStyle = switch (widget.size) {
      ButtonSize.small => SoamaTypography.labelMedium,
      ButtonSize.medium => SoamaTypography.labelLarge,
      ButtonSize.large => SoamaTypography.titleMedium,
    };

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.label,
      child: GestureDetector(
        onTap: isEnabled ? widget.onPressed : null,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _isPressed && !isReducedMotion ? 0.97 : 1.0,
          duration: SoamaMotion.fast,
          curve: SoamaMotion.easeOutSpring,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              color: isEnabled ? colors.accent : colors.accentMuted,
              borderRadius: SoamaRadii.radiusPill,
            ),
            child: Row(
              mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.onAccent),
                    ),
                  ),
                  const SizedBox(width: SoamaSpacing.xs),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: colors.onAccent),
                  const SizedBox(width: SoamaSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle.copyWith(
                      color: colors.onAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonSize size;
  final bool isFullWidth;
  final bool isLoading;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = ButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      HapticFeedback.selectionClick();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isReducedMotion = SoamaMotion.isReducedMotion(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final double height = switch (widget.size) {
      ButtonSize.small => 36.0,
      ButtonSize.medium => 46.0,
      ButtonSize.large => 54.0,
    };

    final double horizontalPadding = switch (widget.size) {
      ButtonSize.small => 14.0,
      ButtonSize.medium => 20.0,
      ButtonSize.large => 26.0,
    };

    final TextStyle textStyle = switch (widget.size) {
      ButtonSize.small => SoamaTypography.labelMedium,
      ButtonSize.medium => SoamaTypography.labelLarge,
      ButtonSize.large => SoamaTypography.titleMedium,
    };

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.label,
      child: GestureDetector(
        onTap: isEnabled ? widget.onPressed : null,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _isPressed && !isReducedMotion ? 0.97 : 1.0,
          duration: SoamaMotion.fast,
          curve: SoamaMotion.easeOutSpring,
          child: GlassSurface(
            borderRadius: SoamaRadii.radiusPill,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: SoamaSpacing.xs),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: colors.textPrimary),
                  const SizedBox(width: SoamaSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
