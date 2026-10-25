import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/models/customer_profile.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/soama_buttons.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late CustomerNotificationPreferences _notifPrefs;

  @override
  void initState() {
    super.initState();
    _notifPrefs = CustomerProfile.current.notificationPreferences;
  }

  void _updatePref({
    bool? bookingAlerts,
    bool? chatAlerts,
    bool? priceOfferUpdates,
    bool? smsReminders,
  }) {
    HapticFeedback.selectionClick();
    setState(() {
      _notifPrefs = _notifPrefs.copyWith(
        bookingAlerts: bookingAlerts,
        chatAlerts: chatAlerts,
        priceOfferUpdates: priceOfferUpdates,
        smsReminders: smsReminders,
      );
      CustomerProfile.current = CustomerProfile.current.copyWith(
        notificationPreferences: _notifPrefs,
      );
    });
  }

  void _showSavedAddressesSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final addresses = CustomerProfile.current.savedAddresses;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13151A) : colors.surface,
                borderRadius: SoamaRadii.sheetTopRadius,
                border: Border.all(color: colors.glassBorder, width: 1.0),
              ),
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: SoamaSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saved Addresses',
                        style: SoamaTypography.titleMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_location_alt_outlined, color: colors.accent, size: 22),
                        tooltip: 'Add Address',
                        onPressed: () => _showAddAddressDialog(context, () {
                          setSheetState(() {});
                          setState(() {});
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: SoamaSpacing.xs),
                  ...addresses.map((addr) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: SoamaRadii.radiusLg,
                          border: Border.all(
                            color: addr.isDefault ? colors.accent : colors.glassBorder,
                            width: addr.isDefault ? 1.4 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              addr.isDefault ? Icons.home_rounded : Icons.place_outlined,
                              color: addr.isDefault ? colors.accent : colors.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(width: SoamaSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        addr.label,
                                        style: SoamaTypography.labelLarge.copyWith(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (addr.isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colors.accent.withOpacity(0.2),
                                            borderRadius: SoamaRadii.radiusPill,
                                          ),
                                          child: Text(
                                            'Default',
                                            style: TextStyle(color: colors.accent, fontSize: 9, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addr.address,
                                    style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Delete button (with confirmation)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteAddress(context, addr, () {
                                setSheetState(() {});
                                setState(() {});
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddAddressDialog(BuildContext context, VoidCallback onUpdated) {
    final colors = context.soamaColors;
    final labelCtrl = TextEditingController(text: 'Warehouse');
    final addrCtrl = TextEditingController(text: 'Plot 12, Refinery Road, Warri, Delta State');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
        title: Text('Add New Address', style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Address Label (e.g. Home, Office, Site)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addrCtrl,
              decoration: const InputDecoration(labelText: 'Street Address in Delta State'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: TextStyle(color: colors.textSecondary))),
          TextButton(
            onPressed: () {
              final newAddr = SavedAddress(
                id: 'addr-${DateTime.now().millisecondsSinceEpoch}',
                label: labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : 'Other',
                address: addrCtrl.text.trim(),
                isDefault: false,
              );
              final currentList = List<SavedAddress>.from(CustomerProfile.current.savedAddresses)..add(newAddr);
              CustomerProfile.current = CustomerProfile.current.copyWith(savedAddresses: currentList);
              onUpdated();
              Navigator.of(ctx).pop();
            },
            child: Text('Add Address', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAddress(BuildContext context, SavedAddress addr, VoidCallback onUpdated) async {
    final colors = context.soamaColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
        title: Text('Delete Address?', style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary)),
        content: Text('Remove "${addr.label}: ${addr.address}" from your saved locations?', style: SoamaTypography.bodyMedium.copyWith(color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: TextStyle(color: colors.textSecondary))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.lightImpact();
      final currentList = List<SavedAddress>.from(CustomerProfile.current.savedAddresses)..removeWhere((a) => a.id == addr.id);
      CustomerProfile.current = CustomerProfile.current.copyWith(savedAddresses: currentList);
      onUpdated();
    }
  }

  void _showFaqSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    final faqs = [
      {
        'q': 'How does Soama Escrow protect my money?',
        'a': 'When you agree on a price, funds are deposited into a secure escrow hold. The specialist is notified to begin work, but funds are only released after you inspect and mark the job completed.',
      },
      {
        'q': 'How are artisans vetted on Soama?',
        'a': 'Every specialist undergoes national identity checks (NIN / CAC) and in-person verification of their past workmanship standards in Delta State.',
      },
      {
        'q': 'What happens if a job is not done to standard?',
        'a': 'You can decline escrow release. Soama Concierge mediation will inspect the work, arrange a re-service, or refund your escrow deposit.',
      },
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13151A) : colors.surface,
          borderRadius: SoamaRadii.sheetTopRadius,
          border: Border.all(color: colors.glassBorder, width: 1.0),
        ),
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: colors.textTertiary.withOpacity(0.3), borderRadius: SoamaRadii.radiusPill),
              ),
            ),
            const SizedBox(height: SoamaSpacing.md),
            Text('Frequently Asked Questions', style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: SoamaSpacing.sm),
            ...faqs.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: SoamaRadii.radiusLg,
                      border: Border.all(color: colors.glassBorder, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f['q']!, style: SoamaTypography.labelLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(f['a']!, style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary, height: 1.35)),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showTermsSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13151A) : colors.surface,
          borderRadius: SoamaRadii.sheetTopRadius,
          border: Border.all(color: colors.glassBorder, width: 1.0),
        ),
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.textTertiary.withOpacity(0.3), borderRadius: SoamaRadii.radiusPill)),
            ),
            const SizedBox(height: SoamaSpacing.md),
            Text('Terms of Service & Escrow Policy', style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: SoamaSpacing.sm),
            Text(
              'Soama operates as a verified peer-to-specialist services marketplace. All monetary transactions are held under escrow agreements until inspection sign-off. Liability coverage covers up to ₦1,000,000 against verified accidental damages during service execution.',
              style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: SoamaSpacing.lg),
            PrimaryButton(label: 'I Understand', size: ButtonSize.large, onPressed: () => Navigator.of(ctx).pop()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas.withOpacity(0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings & Preferences',
          style: SoamaTypography.titleMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Account Section
              _buildSectionHeader('Account'),
              GlassCard(
                borderRadius: SoamaRadii.radiusXl,
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile Information',
                      subtitle: CustomerProfile.current.fullName,
                      onTap: () async {
                        await context.push(AppRoutes.editProfile);
                        setState(() {});
                      },
                    ),
                    _buildDivider(colors.border),
                    _buildSettingsTile(
                      icon: Icons.place_outlined,
                      title: 'Saved Delivery Addresses',
                      subtitle: '${CustomerProfile.current.savedAddresses.length} saved locations',
                      onTap: () => _showSavedAddressesSheet(context),
                    ),
                    _buildDivider(colors.border),
                    _buildSettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change Password',
                      subtitle: 'Available with live authentication',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password security management is enabled with backend authentication.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _buildDivider(colors.border),
                    _buildSettingsTile(
                      icon: Icons.explore_outlined,
                      title: 'Replay Onboarding Tour',
                      subtitle: 'View the 3-step marketplace introduction',
                      onTap: () => context.push(AppRoutes.onboarding),
                    ),
                    _buildDivider(colors.border),
                    _buildSettingsTile(
                      icon: Icons.vpn_key_outlined,
                      title: 'Authentication & Sign In',
                      subtitle: 'Welcome, login, registration & verification screens',
                      onTap: () => context.push(AppRoutes.welcome),
                    ),
                    _buildDivider(colors.border),
                    _buildSettingsTile(
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      subtitle: 'Securely end session on this device',
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // 2. Preferences Section
              _buildSectionHeader('Appearance & Preferences'),
              GlassCard(
                borderRadius: SoamaRadii.radiusXl,
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme Selection', style: SoamaTypography.titleSmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: SoamaSpacing.xs),
                    GlassContainer(
                      borderRadius: SoamaRadii.radiusXl,
                      padding: const EdgeInsets.all(4.0),
                      child: Row(
                        children: [
                          _buildThemeOption('System', Icons.brightness_auto_rounded, currentThemeMode == ThemeMode.system, () {
                            ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                          }),
                          _buildThemeOption('Warm Ivory', Icons.wb_sunny_rounded, currentThemeMode == ThemeMode.light, () {
                            ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                          }),
                          _buildThemeOption('Deep Charcoal', Icons.nightlight_round, currentThemeMode == ThemeMode.dark, () {
                            ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: SoamaSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: SoamaSpacing.sm),
                    Text('Notification Alerts', style: SoamaTypography.titleSmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                    Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Booking Status Updates', style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                            subtitle: Text('Get notified of appointment arrivals and milestones', style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
                            activeThumbColor: colors.accent,
                            value: _notifPrefs.bookingAlerts,
                            onChanged: (val) => _updatePref(bookingAlerts: val),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Chat & Inquiry Alerts', style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                            subtitle: Text('Real-time alerts when artisans reply to messages', style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
                            activeThumbColor: colors.accent,
                            value: _notifPrefs.chatAlerts,
                            onChanged: (val) => _updatePref(chatAlerts: val),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Price Offer Notifications', style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                            subtitle: Text('Alerts when counteroffers or agreements arrive', style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
                            activeThumbColor: colors.accent,
                            value: _notifPrefs.priceOfferUpdates,
                            onChanged: (val) => _updatePref(priceOfferUpdates: val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // 3. Support Section
              _buildSectionHeader('Support & Policies'),
              GlassCard(
                borderRadius: SoamaRadii.radiusXl,
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & FAQ',
                      subtitle: 'Escrow protection and artisan vetting questions',
                      onTap: () => _showFaqSheet(context),
                    ),
                    _buildDivider(colors.border),
                    _buildSettingsTile(
                      icon: Icons.headset_mic_outlined,
                      title: 'Concierge Dispatch Support',
                      subtitle: 'Direct WhatsApp and hotline assistance in Warri',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connecting to Delta State concierge dispatch (+234 800-SOAMA-NG)...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _buildDivider(colors.border),
                    _buildSettingsTile(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service & Escrow Policy',
                      subtitle: 'Artisan liability guarantee & escrow rules',
                      onTap: () => _showTermsSheet(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // 4. About Section
              _buildSectionHeader('About Soama'),
              GlassCard(
                borderRadius: SoamaRadii.radiusXl,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Soama Marketplace', style: SoamaTypography.titleSmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                        Text('Version 1.0.0+1', style: SoamaTypography.labelSmall.copyWith(color: colors.accent, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nigeria’s premier Apple-inspired local-services marketplace connecting verified plumbers, electricians, technicians, and cleaners across Delta State.',
                      style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary, height: 1.35),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: SoamaTypography.titleMedium.copyWith(
          color: context.soamaColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.soamaColors;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: colors.surfaceSecondary, borderRadius: SoamaRadii.radiusMd),
          child: Icon(icon, size: 20, color: colors.textPrimary),
        ),
        title: Text(title, style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: SoamaTypography.bodySmall.copyWith(color: colors.textTertiary)),
        trailing: Icon(Icons.chevron_right_rounded, size: 20, color: colors.textTertiary),
      ),
    );
  }

  Widget _buildThemeOption(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    final colors = context.soamaColors;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : Colors.transparent,
            borderRadius: SoamaRadii.radiusLg,
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? colors.onAccent : colors.textSecondary),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colors.onAccent : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Divider(height: 1, thickness: 0.8, color: color, indent: 64);
  }

  void _confirmLogout(BuildContext context) {
    final colors = context.soamaColors;
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            'Sign Out',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out of your Soama account?',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        await ref.read(authStateProvider.notifier).logout();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully signed out.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          context.go(AppRoutes.welcome);
        }
      }
    });
  }
}
