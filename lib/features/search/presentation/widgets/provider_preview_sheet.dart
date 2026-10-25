import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/service_badge.dart';
import '../../../../shared/widgets/soama_buttons.dart';

class ProviderPreviewSheet extends StatelessWidget {
  final ServiceProvider provider;

  const ProviderPreviewSheet({
    super.key,
    required this.provider,
  });

  static Future<void> show(BuildContext context, ServiceProvider provider) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderPreviewSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151A) : colors.surface,
        borderRadius: SoamaRadii.sheetTopRadius,
        border: Border.all(color: colors.glassBorder, width: 1.0),
      ),
      padding: EdgeInsets.fromLTRB(20.0, 16.0, 20.0, bottomInset > 0 ? bottomInset + 12.0 : 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textTertiary.withOpacity(0.3),
                borderRadius: SoamaRadii.radiusPill,
              ),
            ),
          ),
          const SizedBox(height: SoamaSpacing.lg),

          // Provider Header Row
          Row(
            children: [
              ClipRRect(
                borderRadius: SoamaRadii.radiusXl,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Image(
                    image: ResizeImage(
                      NetworkImage(provider.avatarUrl),
                      width: 180,
                      height: 180,
                    ),
                    fit: BoxFit.cover,
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
                            provider.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SoamaTypography.titleLarge.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (provider.isVerified)
                          Icon(Icons.verified_rounded, size: 18, color: colors.accent),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.businessName,
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
                          label: provider.formattedRatingLabel,
                        ),
                        const SizedBox(width: SoamaSpacing.xs),
                        ServiceBadge(
                          label: provider.badgeTitle,
                          color: colors.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: SoamaSpacing.lg),

          // Service Highlights
          GlassSurface(
            borderRadius: SoamaRadii.radiusLg,
            padding: const EdgeInsets.all(14.0),
            blurIntensity: GlassBlurIntensity.none,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  context,
                  title: 'Distance',
                  value: provider.approximateDistance,
                  icon: Icons.navigation_outlined,
                ),
                Container(height: 28, width: 1, color: colors.border),
                _buildMetric(
                  context,
                  title: 'Starting Rate',
                  value: provider.startingPrice,
                  icon: Icons.payments_outlined,
                ),
                Container(height: 28, width: 1, color: colors.border),
                _buildMetric(
                  context,
                  title: 'Location',
                  value: provider.location.split(',').first,
                  icon: Icons.place_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: SoamaSpacing.md),
          Text(
            'Artisan Specialty',
            style: SoamaTypography.labelLarge.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Specialized in ${provider.profession}. Identity-vetted with backed escrow protection.',
            style: SoamaTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: SoamaSpacing.xl),

          // Actions
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Dismiss',
                  onPressed: () => Navigator.of(context).pop(),
                  size: ButtonSize.large,
                ),
              ),
              const SizedBox(width: SoamaSpacing.sm),
              Expanded(
                child: PrimaryButton(
                  label: 'View Full Profile',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                    context.push(
                      AppRoutes.providerDetailsPath(provider.id),
                      extra: provider,
                    );
                  },
                  size: ButtonSize.large,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final colors = context.soamaColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.accent),
        const SizedBox(height: 4),
        Text(
          value,
          style: SoamaTypography.labelMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          title,
          style: SoamaTypography.labelSmall.copyWith(
            color: colors.textTertiary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
