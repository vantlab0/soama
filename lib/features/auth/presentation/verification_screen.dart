import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/auth_session.dart';
import '../../../shared/models/customer_profile.dart';
import '../../../shared/widgets/soama_buttons.dart';

import 'providers/auth_provider.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  final String? email;

  const VerificationScreen({
    super.key,
    this.email,
  });

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _codeController = TextEditingController(text: '123456');
  String? _codeError;
  int _cooldownSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _timer?.cancel();
    setState(() => _cooldownSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _resendCode() {
    if (_cooldownSeconds > 0) return;
    HapticFeedback.lightImpact();
    _startCooldownTimer();
    final targetEmail = widget.email ?? CustomerProfile.current.email;
    ref.read(authStateProvider.notifier).sendPasswordReset(targetEmail);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification code resent to $targetEmail.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _verifyCode() async {
    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return;

    setState(() => _codeError = null);
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _codeError = 'Please enter the 6-digit code.');
      HapticFeedback.vibrate();
      return;
    } else if (code.length < 6) {
      setState(() => _codeError = 'Code must be 6 digits.');
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.mediumImpact();

    final targetEmail = widget.email ?? CustomerProfile.current.email;
    final success = await ref.read(authStateProvider.notifier).verifyOtp(
      email: targetEmail,
      token: code,
    );

    if (success) {
      ref.read(authSessionProvider.notifier).verifyEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully! Welcome to Soama.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 2),
          ),
        );
        context.go(AppRoutes.home);
      }
    } else {
      if (mounted) {
        final error = ref.read(authStateProvider).errorMessage ?? 'Invalid verification code.';
        setState(() => _codeError = error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final displayEmail = widget.email ?? 'your account email';

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            24.0,
            8.0,
            24.0,
            bottomInset > 0 ? bottomInset + 20.0 : 32.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify Your Email',
                style: SoamaTypography.displaySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit mock code associated with $displayEmail.',
                style: SoamaTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: SoamaSpacing.xl),

              // Mock Code Input
              _buildFieldLabel('6-Digit Verification Code'),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: SoamaTypography.headlineMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10.0,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '123456',
                  hintStyle: TextStyle(
                    color: colors.textTertiary,
                    letterSpacing: 10.0,
                  ),
                  errorText: _codeError,
                  errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                  border: OutlineInputBorder(
                    borderRadius: SoamaRadii.radiusLg,
                    borderSide: BorderSide(color: colors.border, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: SoamaRadii.radiusLg,
                    borderSide: BorderSide(color: colors.border, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: SoamaRadii.radiusLg,
                    borderSide: BorderSide(color: colors.accent, width: 1.4),
                  ),
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Mock notice banner
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: SoamaRadii.radiusLg,
                  border: Border.all(color: colors.border, width: 1.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: colors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mock Mode: enter any 6 digits (pre-filled with 123456) to proceed without live SMTP.',
                        style: SoamaTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: SoamaSpacing.xl),

              // Verify button
              PrimaryButton(
                label: 'Verify & Enter Marketplace',
                size: ButtonSize.large,
                isLoading: ref.watch(authStateProvider).isLoading,
                onPressed: _verifyCode,
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // Resend action with cooldown
              Center(
                child: _cooldownSeconds > 0
                    ? Text(
                        'Resend code in ${_cooldownSeconds}s',
                        style: SoamaTypography.bodySmall.copyWith(
                          color: colors.textTertiary,
                        ),
                      )
                    : TextButton(
                        onPressed: _resendCode,
                        child: Text(
                          'Resend Code',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: SoamaTypography.labelMedium.copyWith(
          color: context.soamaColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
