import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Error state with retry action.
class HaulErrorState extends StatelessWidget {
  const HaulErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.subtitle,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.error,
              ),
            ),
            AppSpacing.gapLg,
            Text(
              title,
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppSpacing.gapXs,
              Text(
                subtitle!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              AppSpacing.gapLg,
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: AppRadius.buttonBorderRadius,
                    boxShadow: AppShadows.button,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppColors.surface,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        'Try Again',
                        style: AppTypography.buttonSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
