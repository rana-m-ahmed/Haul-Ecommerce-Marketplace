import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// Shows a full-screen semi-transparent overlay that blocks interaction
/// and simulates a network delay while cycling status messages.
/// Returns true when processing is successfully completed.
Future<bool> showProcessingOverlay(BuildContext context) async {
  return await Navigator.of(context).push(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      pageBuilder: (context, _, _) => const ProcessingPaymentOverlay(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  ) ?? false;
}

class ProcessingPaymentOverlay extends StatefulWidget {
  const ProcessingPaymentOverlay({super.key});

  @override
  State<ProcessingPaymentOverlay> createState() => _ProcessingPaymentOverlayState();
}

class _ProcessingPaymentOverlayState extends State<ProcessingPaymentOverlay> {
  String _status = 'Contacting your bank...';
  double _progress = 0.2;

  @override
  void initState() {
    super.initState();
    _simulateProcessing();
  }

  Future<void> _simulateProcessing() async {
    // Stage 1
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _status = 'Verifying security...';
      _progress = 0.6;
    });

    // Stage 2
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _status = 'Securing connection...';
      _progress = 0.8;
    });

    // Stage 3
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _status = 'Payment Confirmed!';
      _progress = 1.0;
    });

    // Final pause before closing
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            width: 280,
            padding: AppSpacing.paddingXl,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.cardBorderRadius,
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_progress < 1.0)
                  const CircularProgressIndicator(color: AppColors.accent)
                else
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 48,
                  ),
                AppSpacing.gapLg,
                Text(
                  _status,
                  style: AppTypography.bodyLargeMedium,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapMd,
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
