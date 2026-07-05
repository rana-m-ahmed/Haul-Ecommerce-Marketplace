import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/design/design.dart';
import '../../../shared/widgets/widgets.dart';
import 'processing_payment_overlay.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key, required this.intent});
  final PaymentIntentResponse intent;

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _name = TextEditingController();

  bool _isCvvFocused = false;
  final FocusNode _cvvFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _cardNumber.addListener(() => setState(() {}));
    _expiry.addListener(() => setState(() {}));
    _cvv.addListener(() => setState(() {}));
    _name.addListener(() => setState(() {}));
    
    _cvvFocus.addListener(() {
      setState(() {
        _isCvvFocused = _cvvFocus.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _name.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Remove focus
    FocusScope.of(context).unfocus();

    // Show processing overlay
    final success = await showProcessingOverlay(context);
    if (success && mounted) {
      // Pop this screen and return true to the PaymentMethodScreen
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final totalString = '${widget.intent.currency.toUpperCase()} ${(widget.intent.amount / 100).toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Add Card', style: AppTypography.h3),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.paddingLg.left,
            right: AppSpacing.paddingLg.right,
            top: AppSpacing.paddingLg.top,
            bottom: bottomInset + AppSpacing.paddingLg.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildVisualCard(),
                AppSpacing.gapXl,
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
                      borderSide: BorderSide.none,
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
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (val) => (val == null || val.length != 7) ? 'Invalid expiry' : null,
                      ),
                    ),
                    const SizedBox(width: 1), // 1px separator
                    Expanded(
                      child: TextFormField(
                        controller: _cvv,
                        focusNode: _cvvFocus,
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
                            borderSide: BorderSide.none,
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
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
                ),
                AppSpacing.gapXl,
                HaulButton(
                  label: 'Pay $totalString',
                  icon: const Icon(Icons.lock_outline),
                  onPressed: _submit,
                  fullWidth: true,
                ),
                AppSpacing.gapLg,
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.chipBorderRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('TEST MODE', style: AppTypography.captionMedium.copyWith(color: AppColors.accent)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _isCvvFocused ? 1 : 0),
      duration: const Duration(milliseconds: 400),
      builder: (context, val, child) {
        // val ranges from 0 to 1, representing rotation.
        final rotationY = val * math.pi;
        final isBackVisible = rotationY > math.pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(rotationY),
          alignment: Alignment.center,
          child: isBackVisible ? _buildCardBack() : _buildCardFront(),
        );
      },
    );
  }

  Widget _buildCardFront() {
    final cardNumber = _cardNumber.text.isEmpty ? '**** **** **** ****' : _cardNumber.text;
    final name = _name.text.isEmpty ? 'YOUR NAME' : _name.text.toUpperCase();
    final expiry = _expiry.text.isEmpty ? 'MM / YY' : _expiry.text;

    return _buildCardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.contactless_outlined, color: Colors.white, size: 32),
              Text('Haul Pay', style: AppTypography.h3.copyWith(color: Colors.white, fontStyle: FontStyle.italic)),
            ],
          ),
          const Spacer(),
          Text(
            cardNumber,
            style: AppTypography.h2.copyWith(color: Colors.white, letterSpacing: 2.0),
          ),
          AppSpacing.gapLg,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CARDHOLDER', style: AppTypography.captionMedium.copyWith(color: Colors.white70)),
                    Text(name, style: AppTypography.bodyLargeMedium.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('EXPIRES', style: AppTypography.captionMedium.copyWith(color: Colors.white70)),
                  Text(expiry, style: AppTypography.bodyLargeMedium.copyWith(color: Colors.white)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final cvv = _cvv.text.isEmpty ? '***' : _cvv.text;

    return Transform(
      // Need to flip the back content so it's not mirrored
      transform: Matrix4.identity()..rotateY(math.pi),
      alignment: Alignment.center,
      child: _buildCardBase(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSpacing.gapMd,
            Container(
              height: 48,
              color: Colors.black87,
              margin: const EdgeInsets.symmetric(horizontal: -AppSpacing.lg),
            ),
            AppSpacing.gapLg,
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    color: Colors.white,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      cvv,
                      style: AppTypography.bodyLargeMedium.copyWith(color: Colors.black, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const Spacer(),
            Text(
              'This card is for demonstration purposes only.',
              style: AppTypography.captionMedium.copyWith(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBase({required Widget child}) {
    return Container(
      height: 200,
      width: double.infinity,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;

    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    
    // Stop at 16 digits (19 chars with spaces)
    if (buffer.length > 19) return oldValue;

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;

    final text = newValue.text.replaceAll(' / ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write(' / ');
      }
    }
    
    // Stop at 4 digits (7 chars with spaces)
    if (buffer.length > 7) return oldValue;

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
