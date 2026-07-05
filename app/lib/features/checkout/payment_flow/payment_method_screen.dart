import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/design/design.dart';
import '../../../shared/widgets/widgets.dart';
import 'processing_payment_overlay.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key, required this.intent});
  final PaymentIntentResponse intent;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _selectedMethod = 'card';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Payment Method', style: AppTypography.h3),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How would you like to pay?', style: AppTypography.displaySmall),
              AppSpacing.gapLg,
              _buildMethodTile(
                id: 'card',
                title: 'Credit / Debit Card',
                icon: Icons.credit_card_outlined,
              ),
              AppSpacing.gapMd,
              _buildMethodTile(
                id: 'apple_pay',
                title: 'Apple Pay',
                icon: Icons.apple,
              ),
              AppSpacing.gapMd,
              _buildMethodTile(
                id: 'google_pay',
                title: 'Google Pay',
                icon: Icons.g_mobiledata,
              ),
              const Spacer(),
              HaulButton(
                label: 'Continue',
                fullWidth: true,
                onPressed: () async {
                  if (_selectedMethod == 'card') {
                    final success = await context.push<bool>(
                      '/checkout/add-card',
                      extra: widget.intent,
                    );
                    if (success == true) {
                      if (!context.mounted) return;
                      context.pop(true);
                    }
                  } else {
                    // Simulate native wallet
                    final success = await showProcessingOverlay(context);
                    if (success) {
                      if (!context.mounted) return;
                      context.pop(true);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTile({required String id, required String title, required IconData icon}) {
    final isSelected = _selectedMethod == id;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      borderRadius: AppRadius.cardBorderRadius,
      child: AnimatedContainer(
        duration: AppMotion.durationBase,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorderRadius,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.card : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.accent : AppColors.textPrimary),
            AppSpacing.gapMd,
            Expanded(child: Text(title, style: AppTypography.bodyLargeMedium)),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
