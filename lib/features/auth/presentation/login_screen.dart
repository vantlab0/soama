import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/auth_session.dart';
import '../../../shared/widgets/soama_buttons.dart';

import 'providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'kolawole.adams@soama.ng');
  final _passwordController = TextEditingController(text: 'SoamaPass123');

  bool _obscurePassword = true;
  bool _rememberMe = true;

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool hasError = false;

    if (email.isEmpty) {
      setState(() => _emailError = 'Email address is required.');
      hasError = true;
    } else if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email address.');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      hasError = true;
    } else if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters.');
      hasError = true;
    }

    if (hasError) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.mediumImpact();

    final success = await ref.read(authStateProvider.notifier).login(
      email: email,
      password: password,
      rememberMe: _rememberMe,
    );

    if (success) {
      ref.read(authSessionProvider.notifier).login(
        email: email,
        rememberMe: _rememberMe,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged in as $email.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 2),
          ),
        );
        context.go(AppRoutes.home);
      }
    } else {
      if (mounted) {
        final error = ref.read(authStateProvider).errorMessage ??
            'Invalid email address or password.';
        setState(() => _passwordError = error);
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
                'Welcome Back',
                style: SoamaTypography.displaySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to manage active bookings, negotiated offers, and artisan messages.',
                style: SoamaTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: SoamaSpacing.xl),

              // Email Address
              _buildFieldLabel('Email Address'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                decoration: _buildInputDecoration(
                  hint: 'Enter your email address',
                  errorText: _emailError,
                  prefixIcon: Icons.mail_outline_rounded,
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
                  hint: 'Enter your password',
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

              const SizedBox(height: SoamaSpacing.sm),

              // Remember Me & Forgot Password Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: colors.accent,
                          checkColor: colors.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() => _rememberMe = val ?? false);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remember Me',
                        style: SoamaTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.forgotPassword);
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // Sign In Action
              PrimaryButton(
                label: 'Sign In',
                size: ButtonSize.large,
                isLoading: ref.watch(authStateProvider).isLoading,
                onPressed: _submitLogin,
              ),

              const SizedBox(height: SoamaSpacing.lg),

              // Create Account Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      context.pushReplacement(AppRoutes.register);
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
