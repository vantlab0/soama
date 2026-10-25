import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/widgets/soama_buttons.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _showPolicySheet(BuildContext context) {
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
          border: Border.all(color: colors.border, width: 1.0),
        ),
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
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
            Text(
              'Terms of Service & Privacy Policy',
              style: SoamaTypography.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SoamaSpacing.sm),
            Text(
              'Soama is a verified peer-to-specialist services marketplace operating in Delta State. All client payments are secured under escrow agreements. We do not sell your personal information or contact details to third parties.',
              style: SoamaTypography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: SoamaSpacing.lg),
            PrimaryButton(
              label: 'Close',
              size: ButtonSize.large,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            24.0,
            24.0,
            24.0,
            bottomInset > 0 ? bottomInset + 16.0 : 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // App Logo / Wordmark
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: SoamaRadii.radiusXxl,
                ),
                child: Center(
                  child: Icon(
                    Icons.handyman_rounded,
                    color: colors.onAccent,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: SoamaSpacing.md),
              Text(
                AppConstants.appName.toUpperCase(),
                style: SoamaTypography.headlineMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: SoamaRadii.radiusPill,
                  border: Border.all(color: colors.border, width: 0.8),
                ),
                child: Text(
                  'Verified Services Marketplace • Delta State',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Headline & Supporting Text
              Text(
                'Hire Trusted Artisans.\nEvery Job Escrow Protected.',
                textAlign: TextAlign.center,
                style: SoamaTypography.displaySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: SoamaSpacing.sm),
              Text(
                'Join thousands of residents in Warri, Asaba, and Ughelli who book vetted plumbers, electricians, AC technicians, and cleaners with transparent pricing.',
                textAlign: TextAlign.center,
                style: SoamaTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 40),

              // Auth Actions
              PrimaryButton(
                label: 'Continue with Email',
                size: ButtonSize.large,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.login);
                },
              ),

              const SizedBox(height: SoamaSpacing.sm),

              // Google Sign-In Placeholder
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: SoamaRadii.radiusPill,
                  border: Border.all(color: colors.border, width: 1.0),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: SoamaRadii.radiusPill,
                  child: InkWell(
                    borderRadius: SoamaRadii.radiusPill,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Google Sign-In is a UI preview. External OAuth activates when a backend is integrated.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.border, width: 0.8),
                          ),
                          child: Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Continue with Google (Placeholder)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // Navigation to Register / Guest
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Don’t have an account?',
                    style: SoamaTypography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.register);
                    },
                    child: Text(
                      'Create Account',
                      style: SoamaTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Explore as Guest shortcut
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.go(AppRoutes.home);
                },
                child: Text(
                  'Explore Marketplace as Guest',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Terms & Privacy
              GestureDetector(
                onTap: () => _showPolicySheet(context),
                child: Text(
                  'By continuing, you agree to Soama’s Terms of Service\nand Escrow Privacy Policy',
                  textAlign: TextAlign.center,
                  style: SoamaTypography.bodySmall.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
