import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/service_badge.dart';
import '../../../../shared/widgets/soama_button.dart';

class TopProvidersList extends StatelessWidget {
  final ValueChanged<ServiceProvider>? onProviderTap;

  const TopProvidersList({
    super.key,
    this.onProviderTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: ServiceProvider.nearbyPros.map((pro) {
          return Padding(
            padding: const EdgeInsets.only(bottom: SoamaSpacing.md),
            child: GlassCard(
              onTap: () => onProviderTap?.call(pro),
              borderRadius: SoamaRadii.radiusXl,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: SoamaRadii.radiusLg,
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: Image.network(
                            pro.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark
                                  ? const Color(0xFF262A36)
                                  : const Color(0xFFE4DFD5),
                              child: Icon(
                                Icons.person_rounded,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: SoamaSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    pro.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SoamaTypography.titleMedium.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (pro.isVerified)
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: colors.accent,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pro.businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SoamaTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                ServiceBadge.rating(
                                  label: '${pro.rating} (${pro.reviewCount})',
                                ),
                                const SizedBox(width: SoamaSpacing.xs),
                                ServiceBadge(
                                  label: pro.badgeTitle,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SoamaSpacing.md),
                  Container(
                    height: 1,
                    color: colors.border,
                  ),
                  const SizedBox(height: SoamaSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pro.location,
                            style: SoamaTypography.labelSmall.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            pro.startingPrice,
                            style: SoamaTypography.priceHighlight.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: SoamaSpacing.sm),
                          SoamaButton(
                            label: 'Book',
                            size: SoamaButtonSize.small,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
