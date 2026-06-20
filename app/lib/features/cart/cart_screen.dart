import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import 'providers/cart_controller.dart';
import 'models/cart_item.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Cart', style: AppTypography.h2),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: cartState.when(
        data: (items) {
          if (items.isEmpty) {
            return HaulEmptyState(
              title: 'Your cart is empty',
              subtitle: 'Add something worth hauling home.',
              icon: Icons.shopping_bag_outlined,
              actionLabel: 'Explore products',
              onAction: () => context.go('/home'),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: AppSpacing.paddingLg,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => AppSpacing.gapMd,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CartItemTile(item: item);
                  },
                ),
              ),
              Padding(
                padding: AppSpacing.paddingLg,
                child: HaulButton(
                  label: 'Checkout',
                  onPressed: () => context.push('/checkout'),
                  fullWidth: true,
                ),
              ),
            ],
          );
        },
        loading: () => const _CartLoadingList(),
        error: (e, st) => HaulErrorState(
          title: 'Cart unavailable',
          subtitle: 'Your cached cart is safe. Try loading it again.',
          onRetry: () => ref.invalidate(cartControllerProvider),
        ),
      ),
    );
  }
}

class _CartItemTile extends ConsumerStatefulWidget {
  const _CartItemTile({required this.item});
  final CartItem item;

  @override
  ConsumerState<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<_CartItemTile> {
  Product? _product;
  bool _productFailed = false;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    setState(() => _productFailed = false);
    try {
      final client = ref.read(apiClientProvider);
      final product = await client.getProduct(widget.item.productId);
      if (mounted) {
        setState(() {
          _product = product;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _productFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.item.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppRadius.cardBorderRadius,
        ),
        child: Icon(Icons.delete_outline, color: AppColors.surface),
      ),
      onDismissed: (_) {
        final messenger = ScaffoldMessenger.of(context);
        ref
            .read(cartControllerProvider.notifier)
            .removeItem(widget.item.productId)
            .catchError((e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Failed to remove item: $e')),
              );
            });
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorderRadius,
          boxShadow: AppShadows.card,
        ),
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.cardBorderRadius,
              ),
              child: _product?.primaryImageUrl != null
                  ? ClipRRect(
                      borderRadius: AppRadius.cardBorderRadius,
                      child: Image.network(
                        _product!.primaryImageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.image_outlined),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _product?.name ??
                        (_productFailed
                            ? 'Product details unavailable'
                            : 'Loading product details'),
                    style: AppTypography.bodySmallMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.item.variantId != null) ...[
                    AppSpacing.gapXxs,
                    Text(
                      'Color: ${widget.item.variantId}',
                      style: AppTypography.caption,
                    ),
                  ],
                  AppSpacing.gapXs,
                  Text(
                    '\$${widget.item.priceSnapshot.toStringAsFixed(0)}',
                    style: AppTypography.priceRegular,
                  ),
                  if (_productFailed)
                    TextButton(
                      onPressed: _fetchProduct,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
            AppSpacing.hGapMd,
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: widget.item.quantity > 1
                      ? () {
                          final messenger = ScaffoldMessenger.of(context);
                          ref
                              .read(cartControllerProvider.notifier)
                              .updateQuantity(
                                widget.item.productId,
                                widget.item.quantity - 1,
                              )
                              .catchError((e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              });
                        }
                      : null,
                ),
                Text(
                  widget.item.quantity.toString(),
                  style: AppTypography.bodySmallMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: widget.item.quantity < 20
                      ? () {
                          final messenger = ScaffoldMessenger.of(context);
                          ref
                              .read(cartControllerProvider.notifier)
                              .updateQuantity(
                                widget.item.productId,
                                widget.item.quantity + 1,
                              )
                              .catchError((e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              });
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLoadingList extends StatelessWidget {
  const _CartLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.paddingLg,
      itemCount: 3,
      separatorBuilder: (_, _) => AppSpacing.gapMd,
      itemBuilder: (_, _) => HaulSkeleton.rect(
        width: double.infinity,
        height: 112,
        borderRadius: AppRadius.cardBorderRadius,
      ),
    );
  }
}
