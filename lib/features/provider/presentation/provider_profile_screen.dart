import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/glass_surface.dart';
import 'widgets/role_switcher_pill.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    return ValueListenableBuilder<UserAccount>(
      valueListenable: UserAccount.notifier,
      builder: (context, account, _) {
        final profile = account.providerProfile;

        return Scaffold(
          backgroundColor: colors.canvas,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            title: Text(
              'Provider Profile',
              style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(SoamaSpacing.lg),
              children: [
                // Mode Switcher Card
                const RoleSwitcherCard(),
                const SizedBox(height: SoamaSpacing.lg),

                // Provider Business Header Card
                GlassSurface(
                  padding: const EdgeInsets.all(SoamaSpacing.md),
                  borderRadius: SoamaRadii.radiusLg,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.accent.withAlpha(25),
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.accent.withOpacity(0.4), width: 1.5),
                        ),
                        child: ClipOval(
                          child: (account.avatarUrl != null && account.avatarUrl!.isNotEmpty)
                              ? Image.network(
                                  account.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(Icons.storefront_rounded, color: colors.accent, size: 28),
                                  ),
                                )
                              : Center(
                                  child: Icon(Icons.storefront_rounded, color: colors.accent, size: 28),
                                ),
                        ),
                      ),
                      const SizedBox(width: SoamaSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.businessName ?? 'Adams Precision Works',
                              style: SoamaTypography.titleMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile?.profession ?? 'Service Specialist',
                              style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${profile?.rating ?? 4.9} (${profile?.reviewCount ?? 18} reviews)',
                                  style: SoamaTypography.labelSmall.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SoamaSpacing.md),

                // Mock Verification Status Badge
                GlassSurface(
                  padding: const EdgeInsets.all(SoamaSpacing.md),
                  borderRadius: SoamaRadii.radiusLg,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: SoamaSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Identity Verification: Pending (Mock)',
                              style: SoamaTypography.titleSmall.copyWith(
                                color: const Color(0xFFD97706),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Artisans board review simulated in local test environment.',
                              style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SoamaSpacing.lg),

                // Operational Details Card
                GlassSurface(
                  padding: const EdgeInsets.all(SoamaSpacing.md),
                  borderRadius: SoamaRadii.radiusLg,
                  child: Column(
                    children: [
                      _infoRow(colors, Icons.location_on_outlined, 'Service Area', profile?.serviceArea ?? 'Warri & Effurun Metros'),
                      const Divider(height: 20),
                      _infoRow(colors, Icons.schedule_rounded, 'Working Hours', profile?.workingHours ?? '8:00 AM – 6:00 PM'),
                      const Divider(height: 20),
                      _infoRow(colors, Icons.calendar_today_outlined, 'Working Days', profile?.workingDays ?? 'Mon – Sat'),
                      const Divider(height: 20),
                      _infoRow(
                        colors,
                        Icons.local_shipping_outlined,
                        'Service Delivery',
                        (profile?.supportsVisitCustomer == true && profile?.supportsReceiveCustomer == true)
                            ? 'On-Site Visits & Workshop Drop-offs'
                            : profile?.supportsVisitCustomer == true
                                ? 'On-Site Visits to Client'
                                : 'Workshop Drop-offs',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SoamaSpacing.lg),

                // Action Menu List
                GlassSurface(
                  borderRadius: SoamaRadii.radiusLg,
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.inventory_2_outlined, color: colors.accent),
                          title: Text('My Services Catalog', style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                          subtitle: Text('${profile?.services.length ?? 0} active listings', style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
                          trailing: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push(AppRoutes.providerServices);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.settings_outlined, color: colors.textPrimary),
                          title: Text('Account Settings', style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                          trailing: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push(AppRoutes.settings);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.switch_account_rounded, color: Color(0xFF7C3AED)),
                          title: Text('Switch to Customer Mode', style: SoamaTypography.bodyMedium.copyWith(color: const Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF7C3AED)),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            UserAccount.switchMode(AppMode.customer);
                            context.go(AppRoutes.home);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(SoamaThemeColors colors, IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.textSecondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
            const SizedBox(height: 2),
            Text(value, style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
