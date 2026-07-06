import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/user_repository.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';

class RecommendationSettingsScreen extends ConsumerStatefulWidget {
  const RecommendationSettingsScreen({super.key});

  @override
  ConsumerState<RecommendationSettingsScreen> createState() =>
      _RecommendationSettingsScreenState();
}

class _RecommendationSettingsScreenState
    extends ConsumerState<RecommendationSettingsScreen> {
  Set<String> _selectedCategories = {};
  bool _isSaving = false;
  bool _hasInitialized = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthStateAuthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final uid = authState.uid;
    final userProfileAsync = ref.watch(userProfileProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Recommendation Settings', style: AppTypography.h3),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: userProfileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User profile not found.'));
          }

          if (!_hasInitialized) {
            _selectedCategories = Set.from(profile.preferences);
            _hasInitialized = true;
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tailor your recommendations',
                    style: AppTypography.h2,
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'Select the categories you are most interested in. '
                    'We will use these to personalize your "For You" feed and product suggestions.',
                    style: AppTypography.bodyLarge,
                  ),
                  AppSpacing.gapXl,
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: ProductCategory.values.map((category) {
                          final isSelected =
                              _selectedCategories.contains(category.name);
                          return _CategoryChip(
                            category: category,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedCategories.remove(category.name);
                                } else {
                                  _selectedCategories.add(category.name);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  AppSpacing.gapLg,
                  HaulButton(
                    label: 'Save Changes',
                    isLoading: _isSaving,
                    onPressed: _selectedCategories.isEmpty || _isSaving
                        ? null
                        : _saveChanges,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateAuthenticatedPreferences(_selectedCategories.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update preferences: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final ProductCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.accentSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(category),
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                size: 20,
              ),
              AppSpacing.gapSm,
              Text(
                _getCategoryName(category),
                style: AppTypography.bodyLargeMedium.copyWith(
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryName(ProductCategory category) {
    return category.name[0].toUpperCase() + category.name.substring(1);
  }

  IconData _getCategoryIcon(ProductCategory category) {
    return switch (category) {
      ProductCategory.fashion => Icons.checkroom_rounded,
      ProductCategory.electronics => Icons.devices_rounded,
      ProductCategory.home => Icons.chair_rounded,
      ProductCategory.skincare => Icons.spa_rounded,
      ProductCategory.fitness => Icons.fitness_center_rounded,
      ProductCategory.accessories => Icons.watch_rounded,
    };
  }
}
