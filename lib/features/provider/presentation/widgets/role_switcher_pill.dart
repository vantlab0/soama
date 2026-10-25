import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/glass_surface.dart';

/// Clean Apple-inspired Role Switcher Card and Pill.
/// Allows instant switching between Customer Mode and Provider Mode,
/// or prompts the user to "Become a Service Provider" if not yet enabled.
class RoleSwitcherCard extends StatelessWidget {
  const RoleSwitcherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    return ValueListenableBuilder<UserAccount>(
      valueListenable: UserAccount.notifier,
      builder: (context, account, _) {
        final isProviderMode = account.currentMode == AppMode.provider;
        final hasProviderCapability = account.hasProviderCapability;

        return GlassSurface(
          padding: const EdgeInsets.all(SoamaSpacing.md),
          borderRadius: SoamaRadii.radiusLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isProviderMode ? colors.accent.withAlpha(38) : colors.surfaceSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isProviderMode ? Icons.storefront_rounded : Icons.person_rounded,
                      color: isProviderMode ? colors.accent : colors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: SoamaSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isProviderMode ? 'Provider Workspace' : 'Customer Account',
                          style: SoamaTypography.titleMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isProviderMode
                              ? (account.providerProfile?.businessName ?? 'Specialist Mode Active')
                              : 'Book services, hire specialists & manage jobs',
                          style: SoamaTypography.labelSmall.copyWith(
                            color: colors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isProviderMode ? colors.accent.withAlpha(25) : colors.surfaceSubtle,
                      borderRadius: SoamaRadii.radiusFull,
                      border: Border.all(
                        color: isProviderMode ? colors.accent.withAlpha(80) : colors.glassBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isProviderMode ? 'PRO' : 'CLIENT',
                      style: SoamaTypography.labelSmall.copyWith(
                        color: isProviderMode ? colors.accent : colors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SoamaSpacing.md),
              if (hasProviderCapability) ...[
                // Mode Toggle Segmented Control
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: SoamaRadii.radiusMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isProviderMode) {
                              HapticFeedback.lightImpact();
                              UserAccount.switchMode(AppMode.customer);
                              context.go(AppRoutes.home);
                            }
                          },
                          child: AnimatedContainer(
                            duration: SoamaMotion.snappy,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !isProviderMode ? colors.surface : Colors.transparent,
                              borderRadius: SoamaRadii.radiusSm,
                              boxShadow: !isProviderMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 16,
                                  color: !isProviderMode ? colors.accent : colors.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Customer Mode',
                                  style: SoamaTypography.labelMedium.copyWith(
                                    color: !isProviderMode ? colors.textPrimary : colors.textSecondary,
                                    fontWeight: !isProviderMode ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isProviderMode) {
                              HapticFeedback.lightImpact();
                              UserAccount.switchMode(AppMode.provider);
                              context.go(AppRoutes.home);
                            }
                          },
                          child: AnimatedContainer(
                            duration: SoamaMotion.snappy,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isProviderMode ? colors.surface : Colors.transparent,
                              borderRadius: SoamaRadii.radiusSm,
                              boxShadow: isProviderMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.handyman_outlined,
                                  size: 16,
                                  color: isProviderMode ? colors.accent : colors.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Provider Mode',
                                  style: SoamaTypography.labelMedium.copyWith(
                                    color: isProviderMode ? colors.textPrimary : colors.textSecondary,
                                    fontWeight: isProviderMode ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Prompt to Become a Service Provider
                Container(
                  padding: const EdgeInsets.all(SoamaSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: SoamaRadii.radiusMd,
                    border: Border.all(color: colors.glassBorder, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: colors.accent, size: 22),
                      const SizedBox(width: SoamaSpacing.sm),
                      Expanded(
                        child: Text(
                          'Offer your professional services, set your own prices & receive jobs.',
                          style: SoamaTypography.labelSmall.copyWith(
                            color: colors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SoamaSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.providerOnboarding);
                    },
                    icon: const Icon(Icons.add_business_rounded, size: 18),
                    label: const Text('Become a Service Provider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
