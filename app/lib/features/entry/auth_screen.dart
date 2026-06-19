import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/widgets/widgets.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _onEmailLogin() async {
    if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      try {
        await ref.read(authControllerProvider.notifier).loginWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign in failed: $e')),
          );
        }
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
                'Welcome to Haul',
                style: AppTypography.displaySmall,
              ),
              AppSpacing.gapSm,
              Text(
                'Sign in or continue as a guest to explore curated collections.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              AppSpacing.gapXxl,
              
              // Email field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Type "new" for new user flow',
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
              
              HaulButton(
                label: 'Sign In / Sign Up',
                onPressed: isLoading ? null : _onEmailLogin,
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
                onPressed: isLoading ? null : _onGoogleLogin,
                variant: HaulButtonVariant.secondary,
              ),
              AppSpacing.gapMd,
              
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
