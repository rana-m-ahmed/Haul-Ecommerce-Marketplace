import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: AppMotion.durationBase,
        curve: AppMotion.curveStandard,
      );
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: () => context.go('/auth'),
                  child: Text(
                    'Skip',
                    style: AppTypography.bodySmallMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            
            // Carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _OnboardingPage(
                    icon: Icons.auto_awesome,
                    title: 'Discover with AI',
                    subtitle: 'Find exactly what you want using visual search and smart recommendations tailored just for you.',
                  ),
                  _OnboardingPage(
                    icon: Icons.local_shipping_outlined,
                    title: 'Fast & Reliable',
                    subtitle: 'Get your favorite items delivered quickly with real-time order tracking and secure payments.',
                  ),
                ],
              ),
            ),

            // Pagination dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                return AnimatedContainer(
                  duration: AppMotion.durationFast,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? AppColors.accent : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            
            AppSpacing.gapXl,

            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: HaulButton(
                label: _currentPage == 1 ? 'Get Started' : 'Next',
                onPressed: _onNext,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: AppShadows.card,
            ),
            child: Icon(
              icon,
              size: 64,
              color: AppColors.accent,
            ),
          ),
          AppSpacing.gapXxl,
          Text(
            title,
            style: AppTypography.displaySmall,
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapMd,
          Text(
            subtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
