import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';
import 'glass_container.dart';

enum SoamaButtonVariant {
  primary,   // Chartreuse accent with near-black text
  glass,     // Translucent liquid glass with border
  ghost,     // Minimalist transparent
}

enum SoamaButtonSize {
  small,
  medium,
  large,
}

class SoamaButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SoamaButtonVariant variant;
  final SoamaButtonSize size;
  final bool isFullWidth;
  final bool isLoading;

  const SoamaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = SoamaButtonVariant.primary,
    this.size = SoamaButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
  });

  const SoamaButton.glass({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = SoamaButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
  }) : variant = SoamaButtonVariant.glass;

  const SoamaButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = SoamaButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
  }) : variant = SoamaButtonVariant.ghost;

  @override
  State<SoamaButton> createState() => _SoamaButtonState();
}

class _SoamaButtonState extends State<SoamaButton> {
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

    final double verticalPadding = switch (widget.size) {
      SoamaButtonSize.small => 8.0,
      SoamaButtonSize.medium => 13.0,
      SoamaButtonSize.large => 16.0,
    };

    final double horizontalPadding = switch (widget.size) {
      SoamaButtonSize.small => 14.0,
      SoamaButtonSize.medium => 20.0,
      SoamaButtonSize.large => 26.0,
    };

    final TextStyle textStyle = switch (widget.size) {
      SoamaButtonSize.small => SoamaTypography.labelMedium,
      SoamaButtonSize.medium => SoamaTypography.labelLarge,
      SoamaButtonSize.large => SoamaTypography.titleMedium,
    };

    final Color contentColor = switch (widget.variant) {
      SoamaButtonVariant.primary => colors.onAccent,
      SoamaButtonVariant.glass => colors.textPrimary,
      SoamaButtonVariant.ghost => colors.textSecondary,
    };

    Widget buttonContent = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(contentColor),
            ),
          ),
          const SizedBox(width: SoamaSpacing.xs),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: contentColor),
          const SizedBox(width: SoamaSpacing.xs),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(
              color: contentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    Widget renderedButton;

    if (widget.variant == SoamaButtonVariant.primary) {
      renderedButton = Container(
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        decoration: BoxDecoration(
          color: isEnabled ? colors.accent : colors.accentMuted,
          borderRadius: SoamaRadii.radiusPill,
        ),
        child: buttonContent,
      );
    } else if (widget.variant == SoamaButtonVariant.glass) {
      renderedButton = GlassContainer(
        borderRadius: SoamaRadii.radiusPill,
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        child: buttonContent,
      );
    } else {
      renderedButton = Container(
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        color: Colors.transparent,
        child: buttonContent,
      );
    }

    return GestureDetector(
      onTap: isEnabled ? widget.onPressed : null,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _isPressed && !isReducedMotion ? 0.97 : 1.0,
        duration: SoamaMotion.fast,
        curve: SoamaMotion.easeOutSpring,
        child: renderedButton,
      ),
    );
  }
}
