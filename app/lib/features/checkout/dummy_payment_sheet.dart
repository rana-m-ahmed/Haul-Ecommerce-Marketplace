import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';

Future<bool?> showDummyPaymentSheet(BuildContext context, {required double amount, required String currency}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DummyPaymentSheet(amount: amount, currency: currency),
  );
}

class DummyPaymentSheet extends StatefulWidget {
  const DummyPaymentSheet({super.key, required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  State<DummyPaymentSheet> createState() => _DummyPaymentSheetState();
}

class _DummyPaymentSheetState extends State<DummyPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _name = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    // Simulate network delay for realistic feel
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine bottom padding for keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final totalString = '${widget.currency.toUpperCase()} ${(widget.amount / 100).toStringAsFixed(2)}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: bottomInset + AppSpacing.lg,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSpacing.gapLg,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Details', style: AppTypography.h2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.chipBorderRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('TEST MODE', style: AppTypography.captionMedium.copyWith(color: AppColors.accent)),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              TextFormField(
                controller: _cardNumber,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  _CardNumberFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Card Information',
                  hintText: '0000 0000 0000 0000',
                  prefixIcon: Icon(Icons.credit_card_outlined),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                ),
                validator: (val) => (val == null || val.replaceAll(' ', '').length < 15) ? 'Invalid card number' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiry,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _ExpiryDateFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'MM / YY',
                        hintText: 'MM / YY',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                        ),
                      ),
                      validator: (val) => (val == null || val.length != 7) ? 'Invalid expiry' : null,
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _cvv,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CVC',
                        hintText: '123',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
                        ),
                      ),
                      validator: (val) => (val == null || val.length < 3) ? 'Invalid CVC' : null,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name on card',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
              ),
              AppSpacing.gapXl,
              HaulButton(
                label: 'Pay $totalString',
                icon: const Icon(Icons.lock_outline),
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) text = text.substring(0, 16);
    
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);
    
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write(' / ');
      }
    }
    var string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
