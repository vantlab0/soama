import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/models/chat_conversation.dart';
import '../../../shared/models/customer_profile.dart';
import '../../../shared/models/service_request.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/service_badge.dart';
import '../../provider/presentation/widgets/role_switcher_pill.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final currentThemeMode = ref.watch(themeModeProvider);
    final profile = CustomerProfile.current;

    final totalBookings = ServiceRequest.submittedRequests.length;
    final unreadMessages = ChatConversation.mockConversations
        .where((c) => c.unreadCount > 0)
        .length;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 120.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customer Profile',
                    style: SoamaTypography.displayMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: colors.textPrimary,
                      size: 24,
                    ),
                    tooltip: 'Settings & Preferences',
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await context.push(AppRoutes.settings);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: SoamaSpacing.md),
              const RoleSwitcherCard(),
              const SizedBox(height: SoamaSpacing.md),

              // Main Customer Card
              GlassCard(
                borderRadius: SoamaRadii.radiusXxl,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar or Initials
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.accent.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: profile.avatarUrl != null
                                ? Image.network(
                                    profile.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        profile.initials,
                                        style: SoamaTypography.headlineMedium.copyWith(
                                          color: colors.onAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      profile.initials,
                                      style: SoamaTypography.headlineMedium.copyWith(
                                        color: colors.onAccent,
                                        fontWeight: FontWeight.bold,
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
                                      profile.fullName,
                                      style: SoamaTypography.titleLarge.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const ServiceBadge.verified(label: 'Verified'),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                profile.email,
                                style: SoamaTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${profile.phoneNumber} • ${profile.locationArea}',
                                style: SoamaTypography.bodySmall.copyWith(
                                  color: colors.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SoamaSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: SoamaSpacing.sm),
                    // Edit Profile Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mock Customer Account',
                          style: SoamaTypography.labelSmall.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await context.push(AppRoutes.editProfile);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 6.0,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accent.withOpacity(0.16),
                              borderRadius: SoamaRadii.radiusPill,
                              border: Border.all(
                                color: colors.accent.withOpacity(0.4),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: colors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit Profile',
                                  style: SoamaTypography.labelSmall.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // Concise Account Summary (Metrics Grid)
              Text(
                'Account Activity',
                style: SoamaTypography.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SoamaSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetricCard(
                      context: context,
                      title: 'My Bookings',
                      value: '$totalBookings',
                      subtitle: 'Active & past jobs',
                      icon: Icons.calendar_month_outlined,
                      onTap: () => context.go(AppRoutes.bookings),
                    ),
                  ),
                  const SizedBox(width: SoamaSpacing.sm),
                  Expanded(
                    child: _buildSummaryMetricCard(
                      context: context,
                      title: 'Messages',
                      value: unreadMessages > 0 ? '$unreadMessages unread' : 'All read',
                      subtitle: 'Artisan inquiries',
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () => context.go(AppRoutes.messages),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SoamaSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetricCard(
                      context: context,
                      title: 'Escrow Protection',
                      value: '100% Safe',
                      subtitle: 'Up to ₦1M coverage',
                      icon: Icons.shield_outlined,
                      onTap: () async {
                        await context.push(AppRoutes.settings);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: SoamaSpacing.sm),
                  Expanded(
                    child: _buildSummaryMetricCard(
                      context: context,
                      title: 'Saved Locations',
                      value: '${profile.savedAddresses.length}',
                      subtitle: profile.savedAddresses.isNotEmpty
                          ? profile.savedAddresses.first.label
                          : 'None saved',
                      icon: Icons.place_outlined,
                      onTap: () async {
                        await context.push(AppRoutes.settings);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: SoamaSpacing.xl),

              // Quick Navigation Links
              Text(
                'Quick Navigation',
                style: SoamaTypography.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SoamaSpacing.sm),

              GlassCard(
                borderRadius: SoamaRadii.radiusXxl,
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  children: [
                    _buildNavTile(
                      context: context,
                      icon: Icons.calendar_today_rounded,
                      title: 'My Bookings & Orders',
                      subtitle: 'Track work milestones, counteroffers, and arrivals',
                      badge: totalBookings > 0 ? '$totalBookings' : null,
                      onTap: () => context.go(AppRoutes.bookings),
                    ),
                    _buildDivider(colors.border),
                    _buildNavTile(
                      context: context,
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Messages & Chats',
                      subtitle: 'Direct conversations with verified specialists',
                      badge: unreadMessages > 0 ? '$unreadMessages' : null,
                      onTap: () => context.go(AppRoutes.messages),
                    ),
                    _buildDivider(colors.border),
                    _buildNavTile(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications & Alerts',
                      subtitle: 'Status changes, negotiations, and updates',
                      onTap: () => context.push(AppRoutes.notifications),
                    ),
                    _buildDivider(colors.border),
                    _buildNavTile(
                      context: context,
                      icon: Icons.settings_outlined,
                      title: 'Settings & Preferences',
                      subtitle: 'Theme, saved addresses, alerts & support',
                      onTap: () async {
                        await context.push(AppRoutes.settings);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: SoamaSpacing.xl),

              // Theme Quick Selector
              Text(
                'Appearance & Theme',
                style: SoamaTypography.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select between Warm Ivory or Deep Charcoal Dark mode',
                style: SoamaTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: SoamaSpacing.sm),

              GlassContainer(
                borderRadius: SoamaRadii.radiusXxl,
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    _buildThemeOption(
                      context: context,
                      title: 'System',
                      icon: Icons.brightness_auto_rounded,
                      isSelected: currentThemeMode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system),
                    ),
                    _buildThemeOption(
                      context: context,
                      title: 'Warm Ivory',
                      icon: Icons.wb_sunny_rounded,
                      isSelected: currentThemeMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                    _buildThemeOption(
                      context: context,
                      title: 'Deep Charcoal',
                      icon: Icons.nightlight_round,
                      isSelected: currentThemeMode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.soamaColors;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: GlassCard(
        borderRadius: SoamaRadii.radiusXl,
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: SoamaRadii.radiusSm,
                  ),
                  child: Icon(icon, size: 18, color: colors.accent),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: colors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: SoamaSpacing.sm),
            Text(
              value,
              style: SoamaTypography.headlineSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: SoamaTypography.labelSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: SoamaTypography.bodySmall.copyWith(
                color: colors.textTertiary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    final colors = context.soamaColors;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: SoamaRadii.radiusMd,
          ),
          child: Icon(icon, size: 20, color: colors.textPrimary),
        ),
        title: Text(
          title,
          style: SoamaTypography.bodyMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: SoamaTypography.bodySmall.copyWith(
            color: colors.textTertiary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: SoamaRadii.radiusPill,
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: colors.onAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.soamaColors;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: SoamaMotion.standard,
          curve: SoamaMotion.easeOutSpring,
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : Colors.transparent,
            borderRadius: SoamaRadii.radiusLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colors.onAccent : colors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: SoamaTypography.labelSmall.copyWith(
                  color: isSelected ? colors.onAccent : colors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Divider(
      height: 1,
      thickness: 0.8,
      color: color,
      indent: 64,
    );
  }
}
