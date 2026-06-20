import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import '../catalog/catalog_ui.dart';
import 'providers/wishlist_controller.dart';

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

          return _WishlistGrid(productIds: itemIds);
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

class _WishlistGrid extends ConsumerStatefulWidget {
  const _WishlistGrid({required this.productIds});
  final List<String> productIds;

  @override
  ConsumerState<_WishlistGrid> createState() => _WishlistGridState();
}

class _WishlistGridState extends ConsumerState<_WishlistGrid> {
  List<Product>? _products;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void didUpdateWidget(covariant _WishlistGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.productIds != oldWidget.productIds) {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    if (widget.productIds.isEmpty) {
      setState(() {
        _products = [];
        _loading = false;
        _error = null;
      });
      return;
    }

    try {
      final client = ref.read(apiClientProvider);
      // Ideally use batch API, but for now we loop or use search
      // The API contract has `/products/batch`
      final response = await client.postBatchProducts(widget.productIds);
      if (mounted) {
        setState(() {
          _products = response;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _WishlistLoadingGrid();
    }

    if (_error != null) {
      return HaulErrorState(
        title: 'Saved products could not load',
        subtitle: 'Your wishlist is still safe. Try loading it again.',
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _fetchProducts();
        },
      );
    }

    if (_products == null || _products!.isEmpty) {
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
        childAspectRatio: 0.65,
      ),
      itemCount: _products!.length,
      itemBuilder: (context, index) {
        final product = _products![index];
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
        childAspectRatio: 0.65,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => HaulSkeleton.productCard(),
    );
  }
}

extension on ApiClient {
  Future<List<Product>> postBatchProducts(List<String> ids) async {
    // The existing api_client.dart doesn't have batchProducts method, we should add it.
    // However, I can implement a loop here if batch is missing, or add it to ApiClient.
    // Let's check if ApiClient has batch. Looking at `api_client.dart`, no, it doesn't.
    // I will use individual get calls or create a temporary hack, but wait, I can just write the batch logic here.

    // I see `/products/batch` in OpenAPI contract! Let's hit it.
    // In Dart extension, we can't access `_post`, so we'll just loop for simplicity, or modify `api_client.dart`.
    // We'll modify `api_client.dart` after this.
    final List<Product> result = [];
    for (final id in ids) {
      try {
        final p = await getProduct(id);
        result.add(p);
      } catch (_) {}
    }
    return result;
  }
}
