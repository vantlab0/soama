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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegistration() async {
    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return;

    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    bool hasError = false;

    if (name.isEmpty) {
      setState(() => _nameError = 'Full name is required.');
      hasError = true;
    } else if (name.length < 3) {
      setState(() => _nameError = 'Full name must be at least 3 characters.');
      hasError = true;
    }

    if (email.isEmpty) {
      setState(() => _emailError = 'Email address is required.');
      hasError = true;
    } else if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email address.');
      hasError = true;
    }

    if (phone.isEmpty) {
      setState(() => _phoneError = 'Phone number is required.');
      hasError = true;
    } else if (phone.length < 8) {
      setState(() => _phoneError = 'Please enter a valid phone number (min 8 digits).');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      hasError = true;
    } else if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters.');
      hasError = true;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password.');
      hasError = true;
    } else if (confirmPassword != password) {
      setState(() => _confirmPasswordError = 'Passwords do not match.');
      hasError = true;
    }

    if (hasError) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.mediumImpact();

    final success = await ref.read(authStateProvider.notifier).register(
      fullName: name,
      email: email,
      phone: phone,
      password: password,
    );

    if (success) {
      ref.read(authSessionProvider.notifier).register(email: email, name: name);
      CustomerProfile.current = CustomerProfile.current.copyWith(
        fullName: name,
        email: email,
        phoneNumber: phone,
      );

      if (mounted) {
        final currentAuthState = ref.read(authStateProvider);
        if (currentAuthState.needsVerification) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account created. Verification code sent to $email.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF15803D),
              duration: const Duration(seconds: 3),
            ),
          );
          context.push(
            AppRoutes.verification,
            extra: email,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account created for $email.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF15803D),
              duration: const Duration(seconds: 2),
            ),
          );
          context.push(
            AppRoutes.verification,
            extra: email,
          );
        }
      }
    } else {
      if (mounted) {
        final error = ref.read(authStateProvider).errorMessage ??
            'Registration could not be completed. Please try again.';
        setState(() => _emailError = error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
        );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: SoamaTypography.displaySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Join Soama to book verified specialists with escrow protection across Delta State.',
                style: SoamaTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: SoamaSpacing.xl),

              // Full Name
              _buildFieldLabel('Full Name'),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                decoration: _buildInputDecoration(
                  hint: 'e.g. Kolawole Adams',
                  errorText: _nameError,
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Email Address
              _buildFieldLabel('Email Address'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                decoration: _buildInputDecoration(
                  hint: 'e.g. kola.adams@soama.ng',
                  errorText: _emailError,
                  prefixIcon: Icons.mail_outline_rounded,
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Phone Number
              _buildFieldLabel('Phone Number'),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                decoration: _buildInputDecoration(
                  hint: 'e.g. +234 803 123 4567',
                  errorText: _phoneError,
                  prefixIcon: Icons.phone_outlined,
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Password
              _buildFieldLabel('Password'),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                decoration: _buildInputDecoration(
                  hint: 'Minimum 6 characters',
                  errorText: _passwordError,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: colors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Confirm Password
              _buildFieldLabel('Confirm Password'),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                decoration: _buildInputDecoration(
                  hint: 'Re-enter your password',
                  errorText: _confirmPasswordError,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: colors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),

              const SizedBox(height: SoamaSpacing.xl),

              // Submit Action
              PrimaryButton(
                label: 'Create Account',
                size: ButtonSize.large,
                isLoading: ref.watch(authStateProvider).isLoading,
                onPressed: _submitRegistration,
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // Already have account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: SoamaTypography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.pushReplacement(AppRoutes.login);
                    },
                    child: Text(
                      'Log In',
                      style: SoamaTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
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

  InputDecoration _buildInputDecoration({
    required String hint,
    String? errorText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final colors = context.soamaColors;
    return InputDecoration(
      hintText: hint,
      hintStyle: SoamaTypography.bodySmall.copyWith(color: colors.textTertiary),
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      filled: true,
      fillColor: colors.surface,
      prefixIcon: Icon(prefixIcon, size: 20, color: colors.textSecondary),
      suffixIcon: suffixIcon,
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
    );
  }
}
