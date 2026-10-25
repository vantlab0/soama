import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_category.dart';
import '../../../../shared/widgets/glass_card.dart';

class CategoriesRail extends StatelessWidget {
  final String? selectedCategoryId;
  final ValueChanged<String>? onCategorySelected;

  const CategoriesRail({
    super.key,
    this.selectedCategoryId,
    this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: ServiceCategory.mockCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: SoamaSpacing.sm),
        itemBuilder: (context, index) {
          final cat = ServiceCategory.mockCategories[index];
          final isSelected = cat.id == selectedCategoryId;

          return SizedBox(
            width: 130,
            child: GlassCard(
              onTap: () => onCategorySelected?.call(cat.id),
              borderRadius: SoamaRadii.radiusXl,
              padding: const EdgeInsets.all(12.0),
              backgroundColor: isSelected
                  ? colors.accent.withOpacity(isDark ? 0.22 : 0.16)
                  : null,
              borderColor: isSelected
                  ? colors.accent.withOpacity(0.7)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.accent
                          : (isDark ? const Color(0xFF232733) : const Color(0xFFEEEBE1)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cat.icon,
                      size: 20,
                      color: isSelected ? colors.onAccent : colors.textPrimary,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SoamaTypography.labelLarge.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cat.providerCount}+ pros',
                        style: SoamaTypography.labelSmall.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
