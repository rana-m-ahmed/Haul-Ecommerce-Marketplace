import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import '../catalog/catalog_ui.dart';
import 'providers/wishlist_controller.dart';
import 'providers/wishlist_products_provider.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistState = ref.watch(wishlistControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Wishlist', style: AppTypography.h2),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: wishlistState.when(
        data: (itemIds) {
          if (itemIds.isEmpty) {
            return HaulEmptyState(
              title: 'Your wishlist is empty',
              subtitle: 'Save a few products and they will appear here.',
              icon: Icons.favorite_border_rounded,
              actionLabel: 'Browse products',
              onAction: () => context.go('/home'),
            );
          }

          return const _WishlistGrid();
        },
        loading: () => const _WishlistLoadingGrid(),
        error: (e, st) => HaulErrorState(
          title: 'Wishlist unavailable',
          subtitle: 'We could not load your saved products.',
          onRetry: () => ref.invalidate(wishlistControllerProvider),
        ),
      ),
    );
  }
}

class _WishlistGrid extends ConsumerWidget {
  const _WishlistGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(wishlistProductsProvider);

    return productsAsync.when(
      loading: () => const _WishlistLoadingGrid(),
      error: (e, st) => HaulErrorState(
        title: 'Saved products could not load',
        subtitle: 'Your wishlist is still safe. Try loading it again.',
        onRetry: () => ref.invalidate(wishlistProductsProvider),
      ),
      data: (products) {
        if (products.isEmpty) {
          return const HaulEmptyState(
            title: 'Saved products moved',
            subtitle: 'These items are no longer available in the catalog.',
            icon: Icons.inventory_2_outlined,
          );
        }

        return GridView.builder(
          padding: AppSpacing.paddingLg,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            childAspectRatio: 0.5,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return HaulProductCard(
              data: product.toCardData(isWishlisted: true),
              onTap: () {
                context.push(
                  '/products/${product.id}',
                  extra: ProductRouteExtra(
                    product: product,
                    heroTag: AppMotion.productCardHero(product.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _WishlistLoadingGrid extends StatelessWidget {
  const _WishlistLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: AppSpacing.paddingLg,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        childAspectRatio: 0.5,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => HaulSkeleton.productCard(),
    );
  }
}
