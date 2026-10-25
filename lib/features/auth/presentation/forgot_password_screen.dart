import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/widgets/soama_buttons.dart';
import 'providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController(text: 'kolawole.adams@soama.ng');
  String? _emailError;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submitRecovery() async {
    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return;

    setState(() => _emailError = null);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Email address is required.');
      HapticFeedback.vibrate();
      return;
    } else if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email address.');
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.mediumImpact();

    final success = await ref.read(authStateProvider.notifier).sendPasswordReset(email);
    if (success) {
      if (mounted) {
        setState(() => _isSubmitted = true);
      }
    } else {
      if (mounted) {
        final error = ref.read(authStateProvider).errorMessage ?? 'Unable to send recovery instructions.';
        setState(() => _emailError = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
          child: _isSubmitted ? _buildSuccessView(colors) : _buildFormView(colors),
        ),
      ),
    );
  }

  Widget _buildFormView(SoamaThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reset Password',
          style: SoamaTypography.displaySmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your registered email address to receive password reset instructions.',
          style: SoamaTypography.bodyMedium.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),

        const SizedBox(height: SoamaSpacing.xl),

        _buildFieldLabel('Registered Email Address'),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter your account email',
            hintStyle: SoamaTypography.bodySmall.copyWith(color: colors.textTertiary),
            errorText: _emailError,
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
            filled: true,
            fillColor: colors.surface,
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: colors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
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

        const SizedBox(height: SoamaSpacing.xl),

        PrimaryButton(
          label: 'Send Recovery Instructions',
          size: ButtonSize.large,
          isLoading: ref.watch(authStateProvider).isLoading,
          onPressed: _submitRecovery,
        ),

        const SizedBox(height: SoamaSpacing.lg),

        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Back to Sign In',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(SoamaThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.success.withOpacity(0.16),
            shape: BoxShape.circle,
            border: Border.all(color: colors.success.withOpacity(0.4), width: 1.0),
          ),
          child: Center(
            child: Icon(Icons.mark_email_read_outlined, size: 32, color: colors.success),
          ),
        ),
        const SizedBox(height: SoamaSpacing.lg),
        Text(
          'Recovery Link Sent!',
          style: SoamaTypography.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A simulated password reset message was generated for:',
          textAlign: TextAlign.center,
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          _emailController.text.trim(),
          style: SoamaTypography.titleSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        // Prototype / Mock notice card
        Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: SoamaRadii.radiusLg,
            border: Border.all(color: colors.border, width: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: colors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No actual email was dispatched. When a live backend authentication provider (e.g. Supabase Auth or Firebase) is connected, real SMTP recovery tokens will be sent.',
                  style: SoamaTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        PrimaryButton(
          label: 'Return to Login',
          size: ButtonSize.large,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
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
