import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Haul design system button.
///
/// Variants: [HaulButtonVariant.primary] (coral CTA),
/// [HaulButtonVariant.secondary] (outlined), [HaulButtonVariant.text].
enum HaulButtonVariant { primary, secondary, text }

enum HaulButtonSize { large, small }

class HaulButton extends StatefulWidget {
  const HaulButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = HaulButtonVariant.primary,
    this.size = HaulButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final HaulButtonVariant variant;
  final HaulButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  @override
  State<HaulButton> createState() => _HaulButtonState();
}

class _HaulButtonState extends State<HaulButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppMotion.durationFast,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: AppMotion.curveSpring),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (_isEnabled) _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = widget.size == HaulButtonSize.small;
    final verticalPadding = isSmall ? AppSpacing.xs : AppSpacing.sm;
    final horizontalPadding = isSmall ? AppSpacing.md : AppSpacing.lg;
    final textStyle =
        isSmall ? AppTypography.buttonSmall : AppTypography.buttonLarge;

    final Color backgroundColor;
    final Color foregroundColor;
    final Border? border;

    switch (widget.variant) {
      case HaulButtonVariant.primary:
        backgroundColor =
            _isEnabled ? AppColors.accent : AppColors.accent.withValues(alpha: 0.4);
        foregroundColor = AppColors.surface;
        border = null;
      case HaulButtonVariant.secondary:
        backgroundColor = AppColors.surface;
        foregroundColor =
            _isEnabled ? AppColors.textPrimary : AppColors.disabled;
        border = Border.all(
          color: _isEnabled ? AppColors.border : AppColors.disabled,
          width: 1.5,
        );
      case HaulButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = _isEnabled ? AppColors.accent : AppColors.disabled;
        border = null;
    }

    Widget child;
    if (widget.isLoading) {
      child = SizedBox(
        width: isSmall ? 16.0 : 20.0,
        height: isSmall ? 16.0 : 20.0,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else {
      final label = Text(widget.label, style: textStyle.copyWith(color: foregroundColor));
      if (widget.icon != null) {
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: isSmall ? 16 : 20, color: foregroundColor),
            SizedBox(width: AppSpacing.xs),
            label,
          ],
        );
      } else {
        child = label;
      }
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _isEnabled ? widget.onPressed : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: AppMotion.durationFast,
          curve: AppMotion.curveSpring,
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: horizontalPadding,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.buttonBorderRadius,
            border: border,
            boxShadow: widget.variant == HaulButtonVariant.primary && _isEnabled
                ? AppShadows.button
                : AppShadows.none,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
