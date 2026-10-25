import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';
import '../../shared/models/service_provider.dart';
import 'glass_card.dart';
import 'service_badge.dart';
import 'soama_buttons.dart';

enum ProviderCardLayout {
  compact,  // Horizontal card with quick bottom details (Near you style)
  featured, // Elevated card with larger avatar, business name & reviews
}

class ProviderCard extends StatelessWidget {
  final ServiceProvider provider;
  final VoidCallback? onTap;
  final VoidCallback? onBookTap;
  final ProviderCardLayout layout;

  const ProviderCard({
    super.key,
    required this.provider,
    this.onTap,
    this.onBookTap,
    this.layout = ProviderCardLayout.compact,
  });

  const ProviderCard.featured({
    super.key,
    required this.provider,
    this.onTap,
    this.onBookTap,
  }) : layout = ProviderCardLayout.featured;

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    final double avatarSize = layout == ProviderCardLayout.featured ? 64.0 : 56.0;

    return Semantics(
      button: true,
      label: '${provider.name}, ${provider.profession}, rating ${provider.rating}, starting at ${provider.startingPrice}',
      child: GlassCard(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        enableBlur: false, // Optimized for smooth 60/120fps scrolling list performance
        borderRadius: SoamaRadii.radiusXl,
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optimized Avatar with ResizeImage for minimal GPU memory
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: SoamaRadii.radiusLg,
                      child: SizedBox(
                        width: avatarSize,
                        height: avatarSize,
                        child: Image(
                          image: ResizeImage(
                            NetworkImage(provider.avatarUrl),
                            width: 140,
                            height: 140,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark
                                ? const Color(0xFF232733)
                                : const Color(0xFFE4DFD5),
                            child: Icon(
                              Icons.person_rounded,
                              color: colors.textSecondary,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: SoamaSpacing.md),

                // Details (strictly constrained against overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              provider.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SoamaTypography.titleMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (provider.isVerified)
                            Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: colors.accent,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.profession,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SoamaTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: SoamaSpacing.xs,
                        runSpacing: 4.0,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ServiceBadge.rating(
                            label: provider.formattedRatingLabel,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.navigation_outlined,
                                size: 11,
                                color: colors.textTertiary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                provider.approximateDistance,
                                style: SoamaTypography.labelSmall.copyWith(
                                  color: colors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: SoamaSpacing.sm),
            Container(
              height: 0.8,
              color: colors.border,
            ),
            const SizedBox(height: 8.0),

            // Bottom action row: Location + Price + Book (strictly overflow-proof)
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          provider.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoamaTypography.labelSmall.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SoamaSpacing.xs),
                Flexible(
                  child: Text(
                    provider.startingPrice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoamaTypography.labelLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: SoamaSpacing.sm),
                PrimaryButton(
                  label: 'Book',
                  size: ButtonSize.small,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onBookTap?.call();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
