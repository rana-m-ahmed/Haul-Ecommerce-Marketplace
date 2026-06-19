import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Empty state placeholder with illustration and CTA.
class HaulEmptyState extends StatelessWidget {
  const HaulEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

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
                color: AppColors.border.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.textSecondary,
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
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.gapLg,
              GestureDetector(
                onTap: onAction,
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
                  child: Text(
                    actionLabel!,
                    style: AppTypography.buttonSmall,
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
