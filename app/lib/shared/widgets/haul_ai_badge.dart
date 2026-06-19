import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// AI-generated content indicator badge.
///
/// Shows the sparkle icon with optional label text.
class HaulAiBadge extends StatefulWidget {
  const HaulAiBadge({
    super.key,
    this.label = 'AI Pick',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  State<HaulAiBadge> createState() => _HaulAiBadgeState();
}

class _HaulAiBadgeState extends State<HaulAiBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? AppSpacing.xs : AppSpacing.sm,
            vertical: widget.compact ? 2 : AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentSoft.withValues(alpha: 0.3),
            borderRadius: AppRadius.chipBorderRadius,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: widget.compact ? 10 : 14,
                color: AppColors.accent,
              ),
              if (!widget.compact) ...[
                SizedBox(width: AppSpacing.xxs),
                Text(
                  widget.label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
