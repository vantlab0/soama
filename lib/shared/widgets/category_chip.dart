import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';
import 'glass_card.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    return GlassCard(
      onTap: onTap,
      borderRadius: SoamaRadii.radiusPill,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      backgroundColor: isSelected
          ? (context.isDarkMode ? colors.accent.withOpacity(0.22) : colors.accent.withOpacity(0.18))
          : null,
      borderColor: isSelected
          ? colors.accent.withOpacity(0.6)
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? (context.isDarkMode ? colors.accent : const Color(0xFF4C5B03)) : colors.textSecondary,
          ),
          const SizedBox(width: SoamaSpacing.xs),
          Text(
            label,
            style: SoamaTypography.labelLarge.copyWith(
              color: isSelected
                  ? (context.isDarkMode ? colors.accent : colors.textPrimary)
                  : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
