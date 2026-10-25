import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';
import 'glass_card.dart';

enum ServiceCategoryItemVariant {
  compact,  // Circular icon + label underneath (rail view)
  expanded, // Row with icon, title, subtitle & provider count
  pill,     // Horizontal pill with icon and title
}

class ServiceCategoryItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? subtitle;
  final int? providerCount;
  final bool isSelected;
  final VoidCallback onTap;
  final ServiceCategoryItemVariant variant;

  const ServiceCategoryItem({
    super.key,
    required this.label,
    required this.icon,
    this.subtitle,
    this.providerCount,
    this.isSelected = false,
    required this.onTap,
    this.variant = ServiceCategoryItemVariant.compact,
  });

  const ServiceCategoryItem.compact({
    super.key,
    required this.label,
    required this.icon,
    this.isSelected = false,
    required this.onTap,
  })  : subtitle = null,
        providerCount = null,
        variant = ServiceCategoryItemVariant.compact;

  const ServiceCategoryItem.expanded({
    super.key,
    required this.label,
    required this.icon,
    this.subtitle,
    this.providerCount,
    this.isSelected = false,
    required this.onTap,
  }) : variant = ServiceCategoryItemVariant.expanded;

  const ServiceCategoryItem.pill({
    super.key,
    required this.label,
    required this.icon,
    this.isSelected = false,
    required this.onTap,
  })  : subtitle = null,
        providerCount = null,
        variant = ServiceCategoryItemVariant.pill;

  @override
  State<ServiceCategoryItem> createState() => _ServiceCategoryItemState();
}

class _ServiceCategoryItemState extends State<ServiceCategoryItem> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final isReducedMotion = SoamaMotion.isReducedMotion(context);

    final double targetScale = _isPressed && !isReducedMotion
        ? 0.96
        : (widget.isSelected && !isReducedMotion ? 1.03 : 1.0);

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: '${widget.label} category',
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedScale(
          scale: targetScale,
          duration: SoamaMotion.fast,
          curve: SoamaMotion.easeOutSpring,
          child: switch (widget.variant) {
            ServiceCategoryItemVariant.compact => _buildCompact(context, colors, isDark),
            ServiceCategoryItemVariant.expanded => _buildExpanded(context, colors, isDark),
            ServiceCategoryItemVariant.pill => _buildPill(context, colors, isDark),
          },
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context, SoamaThemeColors colors, bool isDark) {
    return GlassCard(
      onTap: widget.onTap,
      borderRadius: SoamaRadii.radiusXl,
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6.0),
      backgroundColor: widget.isSelected
          ? colors.accent.withOpacity(isDark ? 0.24 : 0.18)
          : null,
      borderColor: widget.isSelected
          ? colors.accent.withOpacity(0.75)
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: SoamaMotion.standard,
            curve: SoamaMotion.easeOutSpring,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colors.accent
                  : (isDark ? const Color(0xFF222631) : const Color(0xFFECE7DB)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 21,
              color: widget.isSelected ? colors.onAccent : colors.textPrimary,
            ),
          ),
          const SizedBox(height: SoamaSpacing.xs),
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: SoamaTypography.labelMedium.copyWith(
              color: widget.isSelected
                  ? (isDark ? colors.accent : const Color(0xFF3F4D02))
                  : colors.textPrimary,
              fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, SoamaThemeColors colors, bool isDark) {
    return GlassCard(
      onTap: widget.onTap,
      borderRadius: SoamaRadii.radiusXl,
      padding: const EdgeInsets.all(16.0),
      backgroundColor: widget.isSelected
          ? colors.accent.withOpacity(isDark ? 0.22 : 0.16)
          : null,
      borderColor: widget.isSelected
          ? colors.accent.withOpacity(0.7)
          : null,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colors.accent
                  : (isDark ? const Color(0xFF222631) : const Color(0xFFECE7DB)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 22,
              color: widget.isSelected ? colors.onAccent : colors.textPrimary,
            ),
          ),
          const SizedBox(width: SoamaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: SoamaTypography.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoamaTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.providerCount != null)
            Text(
              '${widget.providerCount} pros',
              style: SoamaTypography.labelSmall.copyWith(
                color: colors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPill(BuildContext context, SoamaThemeColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? (isDark ? colors.accent.withOpacity(0.24) : colors.accent.withOpacity(0.18))
            : colors.glassSurface,
        borderRadius: SoamaRadii.radiusPill,
        border: Border.all(
          color: widget.isSelected ? colors.accent.withOpacity(0.75) : colors.glassBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon,
            size: 16,
            color: widget.isSelected
                ? (isDark ? colors.accent : const Color(0xFF4C5B03))
                : colors.textSecondary,
          ),
          const SizedBox(width: SoamaSpacing.xs),
          Text(
            widget.label,
            style: SoamaTypography.labelLarge.copyWith(
              color: widget.isSelected
                  ? (isDark ? colors.accent : colors.textPrimary)
                  : colors.textSecondary,
              fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
