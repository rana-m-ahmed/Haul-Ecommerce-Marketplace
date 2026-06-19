import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
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
            return const Center(child: Text('Your cart is empty'));
          }

          return ListView.separated(
            padding: AppSpacing.paddingLg,
            itemCount: items.length,
            separatorBuilder: (context, index) => AppSpacing.gapMd,
            itemBuilder: (context, index) {
              final item = items[index];
              return _CartItemTile(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
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

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    try {
      final client = ref.read(apiClientProvider);
      final product = await client.getProduct(widget.item.productId);
      if (mounted) {
        setState(() {
          _product = product;
        });
      }
    } catch (e) {
      // Handle error implicitly
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
                    _product?.name ?? 'Loading...',
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
