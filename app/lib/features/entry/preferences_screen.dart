import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/widgets/widgets.dart';

const _categories = [
  'fashion',
  'electronics',
  'home',
  'skincare',
  'fitness',
  'accessories',
];

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final Set<String> _selectedCategories = {};

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  Future<void> _onSave() async {
    try {
      await ref.read(authControllerProvider.notifier).completePreferences(
        _selectedCategories.toList(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferences: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        // No back button, user must complete preferences or logout
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
            child: Text(
              'Logout',
              style: AppTypography.bodySmallMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('What do you love?', style: AppTypography.displaySmall),
                  AppSpacing.gapSm,
                  Text(
                    'Pick a few categories to personalize your For You feed.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapXl,
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategories.contains(category);

                  return GestureDetector(
                    onTap: () => _toggleCategory(category),
                    child: AnimatedContainer(
                      duration: AppMotion.durationFast,
                      curve: AppMotion.curveStandard,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : AppColors.surface,
                        borderRadius: AppRadius.cardBorderRadius,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [] : AppShadows.card,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        category[0].toUpperCase() + category.substring(1),
                        style: AppTypography.bodyLarge.copyWith(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: HaulButton(
                label: 'Save & Continue',
                onPressed: _selectedCategories.isNotEmpty ? _onSave : null,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
