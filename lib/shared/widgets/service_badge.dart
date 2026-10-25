import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';

enum ServiceBadgeType {
  verified,
  rating,
  custom,
}

class ServiceBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final ServiceBadgeType type;

  const ServiceBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.type = ServiceBadgeType.custom,
  });

  const ServiceBadge.verified({
    super.key,
    this.label = 'Verified Pro',
  })  : icon = Icons.verified_rounded,
        color = null,
        type = ServiceBadgeType.verified;

  const ServiceBadge.rating({
    super.key,
    required this.label,
  })  : icon = Icons.star_rounded,
        color = null,
        type = ServiceBadgeType.rating;

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    final Color effectiveColor = switch (type) {
      ServiceBadgeType.verified => colors.accent,
      ServiceBadgeType.rating => colors.starGold,
      ServiceBadgeType.custom => color ?? colors.textSecondary,
    };

    final Color backgroundColor = switch (type) {
      ServiceBadgeType.verified => colors.accentMuted,
      ServiceBadgeType.rating => colors.starGold.withOpacity(0.14),
      ServiceBadgeType.custom => (color ?? colors.textSecondary).withOpacity(0.12),
    };

    final Color textColor = switch (type) {
      ServiceBadgeType.verified =>
        context.isDarkMode ? colors.accent : const Color(0xFF5D7103),
      ServiceBadgeType.rating =>
        context.isDarkMode ? colors.starGold : const Color(0xFFB57C00),
      ServiceBadgeType.custom => color ?? colors.textPrimary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: SoamaRadii.radiusPill,
        border: Border.all(
          color: effectiveColor.withOpacity(0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: effectiveColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: SoamaTypography.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
