import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import '../cart/providers/cart_controller.dart';

const _stripeKey = String.fromEnvironment('HAUL_STRIPE_PUBLISHABLE_KEY');

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _postalCode = TextEditingController();
  final _country = TextEditingController(text: 'US');
  PaymentIntentResponse? _intent;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _line1,
      _line2,
      _city,
      _region,
      _postalCode,
      _country,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  ShippingAddress get _address => ShippingAddress(
    line1: _line1.text.trim(),
    line2: _nullable(_line2.text),
    city: _city.text.trim(),
    region: _nullable(_region.text),
    postalCode: _nullable(_postalCode.text),
    country: _country.text.trim().toUpperCase(),
  );

  Future<void> _fetchAuthoritativeSummary() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(apiClientProvider)
          .createPaymentIntent(_address);
      if (!mounted) return;
      setState(() => _intent = intent);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay() async {
    final intent = _intent;
    if (intent == null) return;
    if (_stripeKey.isEmpty) {
      setState(() {
        _error = 'Stripe test checkout is not configured on this build.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'Haul',
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      final order = await ref
          .read(apiClientProvider)
          .confirmOrder(intent.paymentIntentId);
      ref.invalidate(cartControllerProvider);
      if (mounted) context.go('/order-success', extra: order);
    } on StripeException catch (error) {
      if (mounted) {
        setState(() {
          _error =
              error.error.localizedMessage ??
              'Payment was declined. Your cart is safe; try another card.';
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Checkout', style: AppTypography.h2),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: AnimatedSwitcher(
            duration: AppMotion.durationBase,
            child: _intent == null ? _addressStep() : _summaryStep(_intent!),
          ),
        ),
      ),
    );
  }

  Widget _addressStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('address'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Where should it land?', style: AppTypography.displaySmall),
          AppSpacing.gapXs,
          Text(
            'We will re-check your cart and prices before showing a total.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.gapLg,
          _field(_line1, 'Address line 1', required: true),
          _field(_line2, 'Address line 2'),
          _field(_city, 'City', required: true),
          _field(_region, 'State / region'),
          _field(_postalCode, 'Postal code'),
          _field(_country, 'Country code', required: true, country: true),
          if (_error != null) _inlineError(),
          AppSpacing.gapLg,
          HaulButton(
            label: 'Review order',
            onPressed: _loading ? null : _fetchAuthoritativeSummary,
            isLoading: _loading,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryStep(PaymentIntentResponse intent) {
    return Column(
      key: const ValueKey('summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Final check', style: AppTypography.displaySmall),
        AppSpacing.gapXs,
        Text(
          'This total was calculated by Haul from current prices and inventory.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        AppSpacing.gapLg,
        Container(
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorderRadius,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              _summaryRow('Ship to', '${_address.line1}, ${_address.city}'),
              AppSpacing.gapMd,
              Divider(color: AppColors.border),
              AppSpacing.gapMd,
              _summaryRow(
                'Authoritative total',
                _formatMinor(intent.amount, intent.currency),
                strong: true,
              ),
            ],
          ),
        ),
        if (_error != null) _inlineError(),
        AppSpacing.gapLg,
        HaulButton(
          label: 'Pay securely',
          icon: const Icon(Icons.lock_outline),
          onPressed: _loading ? null : _pay,
          isLoading: _loading,
          fullWidth: true,
        ),
        AppSpacing.gapSm,
        HaulButton(
          label: 'Edit address',
          variant: HaulButtonVariant.text,
          onPressed: _loading ? null : () => setState(() => _intent = null),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool country = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        maxLength: country ? 2 : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: AppRadius.buttonBorderRadius,
          ),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return '$label is required';
          if (country && text.length != 2) return 'Use a 2-letter country code';
          return null;
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool strong = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTypography.bodySmall)),
        AppSpacing.hGapMd,
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: strong ? AppTypography.h2 : AppTypography.bodySmallMedium,
          ),
        ),
      ],
    );
  }

  Widget _inlineError() {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.buttonBorderRadius,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.error),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              _error!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.order,
    this.isGuestOverride,
  });
  final ConfirmOrderResponse order;
  final bool? isGuestOverride;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationHero,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest =
        widget.isGuestOverride ??
        (FirebaseAuth.instance.currentUser?.isAnonymous ?? false);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingXl,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: AppMotion.curveSpring,
                ),
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.surface,
                    size: 64,
                  ),
                ),
              ),
              AppSpacing.gapXl,
              Text('Order caught.', style: AppTypography.displayLarge),
              AppSpacing.gapXs,
              Text(
                widget.order.orderNumber,
                style: AppTypography.bodyLargeMedium,
              ),
              AppSpacing.gapXl,
              if (isGuest)
                Container(
                  padding: AppSpacing.paddingLg,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardBorderRadius,
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    children: [
                      Text('Keep your order history', style: AppTypography.h3),
                      AppSpacing.gapXs,
                      Text(
                        'Link an account so this order follows you to every device.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      AppSpacing.gapMd,
                      HaulButton(
                        label: 'Link an account',
                        onPressed: () => context.push('/auth?link=true'),
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
              AppSpacing.gapLg,
              HaulButton(
                label: 'View orders',
                variant: HaulButtonVariant.secondary,
                onPressed: () => context.go('/orders'),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.loadOrders});

  final Future<OrdersResponse> Function()? loadOrders;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late Future<OrdersResponse> _orders;

  @override
  void initState() {
    super.initState();
    _orders = _load();
  }

  Future<OrdersResponse> _load() {
    if (widget.loadOrders != null) return widget.loadOrders!();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Future.value(const OrdersResponse(orders: [], count: 0));
    }
    return ref.read(apiClientProvider).getOrders(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Orders', style: AppTypography.h2),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: FutureBuilder<OrdersResponse>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView.separated(
              padding: AppSpacing.paddingLg,
              itemCount: 3,
              separatorBuilder: (_, _) => AppSpacing.gapMd,
              itemBuilder: (_, _) => HaulSkeleton.rect(
                width: double.infinity,
                height: 128,
                borderRadius: AppRadius.cardBorderRadius,
              ),
            );
          }
          if (snapshot.hasError) {
            return HaulErrorState(
              subtitle: snapshot.error.toString(),
              onRetry: () => setState(() => _orders = _load()),
            );
          }
          final orders = snapshot.data!.orders;
          if (orders.isEmpty) {
            return const HaulEmptyState(
              title: 'No orders yet',
              subtitle: 'Your completed orders will settle here.',
              icon: Icons.receipt_long_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _orders = _load()),
            child: ListView.separated(
              padding: AppSpacing.paddingLg,
              itemCount: orders.length,
              separatorBuilder: (_, _) => AppSpacing.gapMd,
              itemBuilder: (context, index) {
                final order = orders[index];
                return StaggeredListItem(
                  index: index,
                  child: _OrderCard(
                    order: order,
                    onTap: () =>
                        context.push('/orders/${order.orderId}', extra: order),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final OrderSnapshot order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardBorderRadius,
      child: Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorderRadius,
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(order.orderNumber, style: AppTypography.h3),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            AppSpacing.gapSm,
            Text(
              '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            AppSpacing.gapXs,
            Text(
              _formatMoney(order.total, order.currency),
              style: AppTypography.priceRegular,
            ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.order});
  final OrderSnapshot order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(order.orderNumber, style: AppTypography.h3),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _StatusBadge(status: order.status),
          ),
          AppSpacing.gapLg,
          Text('Purchased snapshot', style: AppTypography.h2),
          AppSpacing.gapSm,
          ...order.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.buttonBorderRadius,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity} x ${item.name}',
                          style: AppTypography.bodySmallMedium,
                        ),
                        Text(
                          '${_formatMoney(item.unitPrice, order.currency)} each',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatMoney(item.subtotal, order.currency),
                    style: AppTypography.bodySmallMedium,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapMd,
          Row(
            children: [
              Expanded(child: Text('Paid total', style: AppTypography.h3)),
              Text(
                _formatMoney(order.total, order.currency),
                style: AppTypography.h2,
              ),
            ],
          ),
          AppSpacing.gapLg,
          Text('Ship to', style: AppTypography.h3),
          AppSpacing.gapXs,
          Text(
            '${order.shippingAddress.line1}\n${order.shippingAddress.city}, '
            '${order.shippingAddress.region ?? ''} ${order.shippingAddress.postalCode ?? ''}\n'
            '${order.shippingAddress.country}',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'canceled' ? AppColors.error : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.chipBorderRadius,
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTypography.captionMedium.copyWith(color: color),
      ),
    );
  }
}

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatMinor(int amount, String currency) =>
    _formatMoney(amount / 100, currency);

String _formatMoney(double amount, String currency) =>
    '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
