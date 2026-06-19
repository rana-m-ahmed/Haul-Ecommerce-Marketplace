import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Spring-animated bottom sheet with the Warm Signal look.
///
/// Usage:
/// ```dart
/// HaulBottomSheet.show(
///   context: context,
///   builder: (context) => YourContent(),
/// );
/// ```
class HaulBottomSheet extends StatelessWidget {
  const HaulBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
  });

  final Widget child;
  final String? title;
  final bool showHandle;

  /// Show a Haul-styled bottom sheet with spring slide-up animation.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool showHandle = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: AppMotion.durationSlow,
      ),
      builder: (context) => HaulBottomSheet(
        title: title,
        showHandle: showHandle,
        child: builder(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.durationSlow,
      curve: AppMotion.curveSpring,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.bottomSheetBorderRadius,
        boxShadow: AppShadows.elevated,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.chipBorderRadius,
                  ),
                ),
              ),

            // Title
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title!, style: AppTypography.h2),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
