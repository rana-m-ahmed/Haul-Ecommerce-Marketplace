import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import 'providers/cart_controller.dart';
import 'models/cart_item.dart';
import '../product/product_provider.dart';

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

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(item.productId));

    return Dismissible(
      key: ValueKey(item.productId),
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
            .removeItem(item.productId)
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
              child: productAsync.when(
                loading: () => HaulSkeleton.rect(width: 80, height: 80, borderRadius: AppRadius.cardBorderRadius),
                error: (_, _) => const Icon(Icons.error_outline),
                data: (product) => product.primaryImageUrl != null
                    ? ClipRRect(
                        borderRadius: AppRadius.cardBorderRadius,
                        child: CachedNetworkImage(
                          imageUrl: product.primaryImageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          errorWidget: (context, url, error) => const Icon(Icons.image_not_supported_outlined),
                          placeholder: (context, url) => Container(color: AppColors.shimmerBase),
                        ),
                      )
                    : const Icon(Icons.image_outlined),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  productAsync.when(
                    loading: () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HaulSkeleton.rect(width: 120, height: 14),
                        AppSpacing.gapXs,
                        HaulSkeleton.rect(width: 80, height: 14),
                      ],
                    ),
                    error: (_, _) => Text('Product details unavailable', style: AppTypography.bodySmallMedium),
                    data: (product) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: AppTypography.bodySmallMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.variantId != null) ...[
                          AppSpacing.gapXxs,
                          Text(
                            'Color: ${item.variantId}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.gapXs,
                  Text(
                    '\$${item.priceSnapshot.toStringAsFixed(0)}',
                    style: AppTypography.priceRegular,
                  ),
                ],
              ),
            ),
            AppSpacing.hGapMd,
            Row(
              children: [
                  if (item.quantity > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        ref
                            .read(cartControllerProvider.notifier)
                            .updateQuantity(
                              item.productId,
                              item.quantity - 1,
                            )
                            .catchError((e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            });
                      },
                    )
                  else
                    const IconButton(
                      icon: Icon(Icons.remove_circle_outline),
                      onPressed: null,
                    ),
                  Text(
                    item.quantity.toString(),
                    style: AppTypography.bodySmallMedium,
                  ),
                  if (item.quantity < 20)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        ref
                            .read(cartControllerProvider.notifier)
                            .updateQuantity(
                              item.productId,
                              item.quantity + 1,
                            )
                            .catchError((e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            });
                      },
                    )
                  else
                    const IconButton(
                      icon: Icon(Icons.add_circle_outline),
                      onPressed: null,
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
