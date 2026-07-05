import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import '../catalog/catalog_ui.dart';
import '../cart/models/cart_item.dart';
import '../cart/providers/cart_controller.dart';
import 'product_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
    this.heroTag,
  });

  final String productId;
  final Product? initialProduct;
  final String? heroTag;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cartController;
  Product? _lastProduct;
  String? _selectedColor;
  int _quantity = 1;
  bool _handledMissing = false;
  String? _explanationRequestedFor;
  ExplainProductResponse? _explanation;
  bool _explanationVisible = false;
  bool _isAddedToCart = false;

  @override
  void initState() {
    super.initState();
    _lastProduct = widget.initialProduct;
    _cartController = AnimationController(
      vsync: this,
      duration: AppMotion.durationBase,
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _cartController.dispose();
    super.dispose();
  }

  Future<void> _bounceCart() async {
    await _cartController.animateTo(
      0.95,
      duration: AppMotion.durationFast,
      curve: AppMotion.curveStandard,
    );
    await _cartController.animateTo(
      1.0,
      duration: AppMotion.durationBase,
      curve: AppMotion.curveSpring,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productDetailProvider(widget.productId));

    return detail.when(
      data: (product) {
        _lastProduct = product;
        _selectedColor ??= product.colors.isEmpty ? null : product.colors.first;
        _scheduleExplanation(product);
        return _buildScaffold(product);
      },
      loading: () {
        final product = _lastProduct;
        if (product != null) {
          return _buildScaffold(product, isRefreshing: true);
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(backgroundColor: AppColors.background),
          body: _buildLoading(),
        );
      },
      error: (error, stackTrace) {
        if (error is ApiException && error.statusCode == 404) {
          _handleMissingProduct();
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(backgroundColor: AppColors.background),
          body: HaulErrorState(
            subtitle: 'Product details could not load.',
            onRetry: () =>
                ref.invalidate(productDetailProvider(widget.productId)),
          ),
        );
      },
    );
  }

  void _scheduleExplanation(Product product) {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthStateAuthenticated ||
        _explanationRequestedFor == product.id) {
      return;
    }
    _explanationRequestedFor = product.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(AppMotion.durationBase);
      if (!mounted) return;
      try {
        final response = await ref.read(
          productExplanationProvider((
            uid: auth.uid,
            productId: product.id,
          )).future,
        );
        if (!mounted) return;
        setState(() {
          _explanation = response;
          _explanationVisible = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _explanationVisible = true);
        });
      } on ApiException catch (error) {
        if (error.statusCode != 404 && mounted) {
          // Explanations are supplementary and must never block the product.
          _explanation = null;
        }
      } catch (_) {
        // Hide gracefully on network/provider failures.
      }
    });
  }

  void _handleMissingProduct() {
    if (_handledMissing) {
      return;
    }
    _handledMissing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product not found.')));
      context.go('/home');
    });
  }

  Widget _buildScaffold(Product product, {bool isRefreshing = false}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: AppSpacing.xxxl * 5,
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                flexibleSpace: FlexibleSpaceBar(
                  background: _ProductGallery(
                    product: product,
                    heroTag:
                        widget.heroTag ?? AppMotion.productCardHero(product.id),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxxl * 2,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isRefreshing)
                        LinearProgressIndicator(color: AppColors.accent),
                      Text(
                        product.category.label,
                        style: AppTypography.captionMedium,
                      ),
                      AppSpacing.gapXs,
                      Text(product.name, style: AppTypography.displaySmall),
                      AppSpacing.gapSm,
                      _PriceLine(product: product),
                      AppSpacing.gapSm,
                      _RatingLine(product: product),
                      AppSpacing.gapLg,
                      Text(product.description, style: AppTypography.bodyLarge),
                      AppSpacing.gapLg,
                      _VariantSelector(
                        colors: product.colors,
                        selectedColor: _selectedColor,
                        onSelected: (value) => setState(() {
                          _selectedColor = value;
                        }),
                      ),
                      AppSpacing.gapLg,
                      _QuantitySelector(
                        quantity: _quantity,
                        onChanged: (val) => setState(() => _quantity = val),
                      ),
                      AppSpacing.gapLg,
                      _MetadataChips(product: product),
                      AppSpacing.gapLg,
                      if (_explanation != null)
                        _AiExplanationSection(
                          explanation: _explanation!,
                          visible: _explanationVisible,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: ScaleTransition(
              scale: _cartController,
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.cardBorderRadius,
                  boxShadow: AppShadows.elevated,
                ),
                child: AnimatedSwitcher(
                  duration: AppMotion.durationFast,
                  child: _isAddedToCart
                      ? Container(
                          key: const ValueKey('success'),
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: AppRadius.buttonBorderRadius,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.surface),
                              AppSpacing.hGapSm,
                              Text(
                                'Added $_quantity item${_quantity == 1 ? '' : 's'} to cart',
                                style: AppTypography.bodyLargeMedium.copyWith(color: AppColors.surface),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          key: const ValueKey('idle'),
                          children: [
                            Flexible(
                              child: _PriceLine(product: product, compact: true, multiplier: _quantity),
                            ),
                            AppSpacing.hGapMd,
                            Expanded(
                              flex: 2,
                              child: HaulButton(
                                label: product.isOutOfStock
                                    ? 'Out of Stock'
                                    : 'Add to Cart',
                                onPressed: product.isOutOfStock ? null : () async {
                                  final item = CartItem(
                                    productId: product.id,
                                    variantId: _selectedColor,
                                    quantity: _quantity,
                                    priceSnapshot: product.salePrice ?? product.price,
                                  );
                                  try {
                                    await ref.read(cartControllerProvider.notifier).addItem(item);
                                    _bounceCart();
                                    if (mounted) {
                                      setState(() => _isAddedToCart = true);
                                      Future.delayed(const Duration(seconds: 2), () {
                                        if (mounted) {
                                          setState(() => _isAddedToCart = false);
                                        }
                                      });
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to add to cart')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: AppSpacing.paddingLg,
      children: [
        HaulSkeleton.rect(
          width: double.infinity,
          height: AppSpacing.xxxl * 5,
          borderRadius: AppRadius.cardBorderRadius,
        ),
        AppSpacing.gapLg,
        HaulSkeleton.rect(width: double.infinity, height: AppSpacing.xl),
        AppSpacing.gapSm,
        HaulSkeleton.rect(width: AppSpacing.xxxl * 2, height: AppSpacing.lg),
      ],
    );
  }
}

class _ProductGallery extends StatelessWidget {
  const _ProductGallery({required this.product, required this.heroTag});

  final Product product;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: Material(
        color: AppColors.surface,
        child: PageView.builder(
          itemCount: product.imageUrls.isEmpty ? 1 : product.imageUrls.length,
          itemBuilder: (context, index) {
            final imageUrl = product.imageUrls.isEmpty
                ? null
                : product.imageUrls[index];
            return imageUrl == null
                ? const _ImagePlaceholder()
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    errorWidget: (context, url, error) =>
                        const _ImagePlaceholder(),
                    placeholder: (context, url) => Container(color: AppColors.shimmerBase),
                  );
          },
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.border,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
        size: AppSpacing.xxxl,
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.product, this.compact = false, this.multiplier = 1});

  final Product product;
  final bool compact;
  final int multiplier;

  @override
  Widget build(BuildContext context) {
    final priceStyle = compact ? AppTypography.priceRegular : AppTypography.h2;
    if (product.isSale && product.salePrice != null) {
      return Row(
        children: [
          Text(
            '\$${(product.salePrice! * multiplier).toStringAsFixed(0)}',
            style: priceStyle.copyWith(color: AppColors.accent),
          ),
          AppSpacing.hGapXs,
          Text(
            '\$${(product.price * multiplier).toStringAsFixed(0)}',
            style: AppTypography.priceOriginalStrikethrough,
          ),
        ],
      );
    }
    return Text('\$${(product.price * multiplier).toStringAsFixed(0)}', style: priceStyle);
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.star_rounded, color: AppColors.accent, size: AppSpacing.lg),
        AppSpacing.hGapXxs,
        Text(
          product.rating.toStringAsFixed(1),
          style: AppTypography.bodySmallMedium,
        ),
        AppSpacing.hGapXs,
        Text(
          '${product.reviewCount} reviews',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _VariantSelector extends StatelessWidget {
  const _VariantSelector({
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<String> colors;
  final String? selectedColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: AppTypography.h3),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final color in colors)
              ChoiceChip(
                label: Text(color),
                selected: selectedColor == color,
                onSelected: (_) => onSelected(color),
              ),
          ],
        ),
      ],
    );
  }
}

class _MetadataChips extends StatelessWidget {
  const _MetadataChips({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final values = [
      ...product.materials,
      ...product.style,
      ...product.tags,
    ].take(8);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final value in values)
          Chip(
            label: Text(value),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.border),
          ),
      ],
    );
  }
}

class _AiExplanationSection extends StatelessWidget {
  const _AiExplanationSection({
    required this.explanation,
    required this.visible,
  });

  final ExplainProductResponse explanation;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: AppMotion.durationSlow,
      curve: AppMotion.curveStandard,
      offset: visible ? Offset.zero : const Offset(0, 0.12),
      child: AnimatedOpacity(
        duration: AppMotion.durationSlow,
        curve: AppMotion.curveStandard,
        opacity: visible ? 1 : 0,
        child: Container(
          key: const ValueKey('ai-explanation'),
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HaulAiBadge(
                label: explanation.provider == 'template'
                    ? 'Style signal'
                    : 'Why it fits',
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Text(
                  explanation.explanationText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity', style: AppTypography.h3),
        AppSpacing.gapSm,
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.buttonBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded),
                onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
                color: AppColors.textPrimary,
                disabledColor: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  quantity.toString(),
                  style: AppTypography.bodyLargeMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: quantity < 99 ? () => onChanged(quantity + 1) : null,
                color: AppColors.textPrimary,
                disabledColor: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
