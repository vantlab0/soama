import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/auth_session.dart';
import '../../../shared/widgets/service_badge.dart';
import '../../../shared/widgets/soama_buttons.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    ref.read(authSessionProvider.notifier).completeOnboarding();
    context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: colors.textPrimary,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              )
            : null,
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _finishOnboarding();
            },
            child: Text(
              'Skip',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // PageView Area
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPage1(colors, isDark),
                  _buildPage2(colors, isDark),
                  _buildPage3(colors, isDark),
                ],
              ),
            ),

            // Bottom Navigation & Actions Area
            Padding(
              padding: EdgeInsets.fromLTRB(
                24.0,
                12.0,
                24.0,
                bottomInset > 0 ? bottomInset + 12.0 : 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: isActive ? 24.0 : 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          color: isActive ? colors.accent : colors.border,
                          borderRadius: SoamaRadii.radiusPill,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: SoamaSpacing.lg),

                  // Action Button
                  PrimaryButton(
                    label: _currentPage == 2 ? 'Get Started' : 'Continue',
                    size: ButtonSize.large,
                    onPressed: _onNextPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 1 — Find Trusted Professionals
  Widget _buildPage1(SoamaThemeColors colors, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        children: [
          const SizedBox(height: SoamaSpacing.sm),
          // Illustration Composition
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: SoamaRadii.radiusXxl,
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.plumbing_rounded,
                              color: colors.onAccent,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ochuko Efe',
                              style: SoamaTypography.titleSmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Master Plumber • Effurun, Warri',
                              style: SoamaTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const ServiceBadge.verified(label: 'NIN Vetted'),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFeatureTag(colors, Icons.star_rounded, '4.95 Rating', colors.starGold),
                    _buildFeatureTag(colors, Icons.security_rounded, 'Background Checked', colors.success),
                    _buildFeatureTag(colors, Icons.schedule_rounded, 'Rapid Response', colors.accent),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTradeChip(colors, 'Plumbing & Pumps'),
                    _buildTradeChip(colors, 'Electricals'),
                    _buildTradeChip(colors, 'Home Cleaning'),
                    _buildTradeChip(colors, 'Auto Mechanic'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: SoamaSpacing.xl),

          // Text Content
          Text(
            'Find Trusted Professionals\nin Delta State',
            textAlign: TextAlign.center,
            style: SoamaTypography.displaySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: SoamaSpacing.sm),
          Text(
            'Discover verified Nigerian artisans for home repairs, electrical works, generator servicing, and deep cleaning. Every specialist is vetted for identity and workmanship.',
            textAlign: TextAlign.center,
            style: SoamaTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // Page 2 — Agree on the Price
  Widget _buildPage2(SoamaThemeColors colors, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        children: [
          const SizedBox(height: SoamaSpacing.sm),
          // Interactive Price Negotiation Preview Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: SoamaRadii.radiusXxl,
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Price Negotiation Flow',
                      style: SoamaTypography.labelLarge.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.accent.withOpacity(0.2),
                        borderRadius: SoamaRadii.radiusPill,
                      ),
                      child: Text(
                        'Agreed & Locked',
                        style: TextStyle(
                          color: isDark ? colors.accent : const Color(0xFF283400),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Message 1 (Artisan Quote)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ochuko Efe (Plumber)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textSecondary)),
                        const SizedBox(height: 2),
                        Text('Initial inspection quote: ₦18,000 with materials.', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Message 2 (Customer Counteroffer)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Your Counteroffer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.onAccent.withOpacity(0.8))),
                        const SizedBox(height: 2),
                        Text('I already have the PVC pipes. ₦15,000?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onAccent)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.success.withOpacity(0.12),
                    borderRadius: SoamaRadii.radiusMd,
                    border: Border.all(color: colors.success.withOpacity(0.3), width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: colors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Agreed Price: ₦15,000 • Held in Escrow',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: SoamaSpacing.xl),

          // Text Content
          Text(
            'Agree on the Price\nBefore Work Starts',
            textAlign: TextAlign.center,
            style: SoamaTypography.displaySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: SoamaSpacing.sm),
          Text(
            'No surprise bills or arguments on site. Chat directly with your specialist, clarify scope, review transparent counteroffers, and lock in the cost in advance.',
            textAlign: TextAlign.center,
            style: SoamaTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // Page 3 — Get the Job Done
  Widget _buildPage3(SoamaThemeColors colors, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        children: [
          const SizedBox(height: SoamaSpacing.sm),
          // Escrow & Milestone Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: SoamaRadii.radiusXxl,
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.accent.withOpacity(0.2),
                        borderRadius: SoamaRadii.radiusLg,
                      ),
                      child: Icon(Icons.shield_outlined, color: colors.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Soama Escrow Protection',
                            style: SoamaTypography.titleSmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₦1,000,000 Artisan Liability Guarantee',
                            style: SoamaTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: SoamaRadii.radiusLg,
                    border: Border.all(color: colors.border, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Arrival Security Passcode', style: TextStyle(fontSize: 10, color: colors.textTertiary)),
                          const SizedBox(height: 2),
                          Text('SEC-3091', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary, letterSpacing: 1.2)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: SoamaRadii.radiusPill,
                        ),
                        child: Text(
                          'Release on Inspection',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.onAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: SoamaSpacing.xl),

          // Text Content
          Text(
            'Get the Job Done with\nEscrow Peace of Mind',
            textAlign: TextAlign.center,
            style: SoamaTypography.displaySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: SoamaSpacing.sm),
          Text(
            'Your money is safely held in escrow and only released when you inspect and confirm satisfaction. Real-time updates, arrival passcodes, and verified reviews ensure quality.',
            textAlign: TextAlign.center,
            style: SoamaTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTag(SoamaThemeColors colors, IconData icon, String text, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTradeChip(SoamaThemeColors colors, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: SoamaRadii.radiusPill,
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary),
      ),
    );
  }
}
