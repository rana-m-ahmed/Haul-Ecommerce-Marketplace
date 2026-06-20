import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design/design.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/widgets/widgets.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.linkMode = false});

  final bool linkMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _onGuestLogin() async {
    try {
      await ref.read(authControllerProvider.notifier).loginAsGuest();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in as guest: $e')),
        );
      }
    }
  }

  Future<void> _onEmailSubmit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    
    if (_isSignUp) {
      if (_usernameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a username')));
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }
      try {
        await ref.read(authControllerProvider.notifier).signUpWithEmail(
          _emailController.text,
          _passwordController.text,
          _usernameController.text,
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
      }
    } else {
      try {
        await ref.read(authControllerProvider.notifier).loginWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
      }
    }
  }

  Future<void> _onGoogleLogin() async {
    try {
      await ref.read(authControllerProvider.notifier).loginWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign in failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthStateLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.linkMode ? 'Save your Haul history' : 'Welcome to Haul',
                style: AppTypography.displaySmall,
              ),
              AppSpacing.gapSm,
              Text(
                widget.linkMode
                    ? 'Link this guest session to a new account without losing your order.'
                    : 'Sign in or continue as a guest to explore curated collections.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              AppSpacing.gapXxl,
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = false),
                    child: Text('Sign In', style: AppTypography.bodyLarge.copyWith(fontWeight: !_isSignUp ? FontWeight.bold : FontWeight.normal, color: !_isSignUp ? AppColors.accent : AppColors.textSecondary)),
                  ),
                  AppSpacing.hGapLg,
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = true),
                    child: Text('Sign Up', style: AppTypography.bodyLarge.copyWith(fontWeight: _isSignUp ? FontWeight.bold : FontWeight.normal, color: _isSignUp ? AppColors.accent : AppColors.textSecondary)),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              if (_isSignUp) ...[
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.cardBorderRadius,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.cardBorderRadius,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                AppSpacing.gapMd,
              ],

              // Email field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.cardBorderRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.cardBorderRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              AppSpacing.gapMd,
              
              // Password field
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.cardBorderRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.cardBorderRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                obscureText: true,
              ),
              AppSpacing.gapLg,
              
              if (_isSignUp) ...[
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.cardBorderRadius,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.cardBorderRadius,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                  obscureText: true,
                ),
                AppSpacing.gapLg,
              ],

              HaulButton(
                label: _isSignUp ? 'Sign Up' : 'Sign In',
                onPressed: isLoading ? null : _onEmailSubmit,
                isLoading: isLoading,
              ),
              AppSpacing.gapXl,
              
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text('OR', style: AppTypography.captionMedium),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              AppSpacing.gapXl,
              
              HaulButton(
                label: 'Continue with Google',
                icon: SvgPicture.asset(
                  'assets/icons/google.svg',
                  width: 20,
                  height: 20,
                ),
                onPressed: isLoading ? null : _onGoogleLogin,
                variant: HaulButtonVariant.secondary,
              ),
              AppSpacing.gapMd,
              
              if (!widget.linkMode)
                HaulButton(
                  label: 'Continue as Guest',
                  onPressed: isLoading ? null : _onGuestLogin,
                  variant: HaulButtonVariant.text,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
