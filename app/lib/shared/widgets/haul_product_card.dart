import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../features/wishlist/providers/wishlist_controller.dart';
import 'haul_ai_badge.dart';

/// Product card layout variant.
enum HaulCardVariant {
  /// Standard vertical grid card.
  grid,

  /// Compact horizontal card for horizontal scroll lists.
  horizontal,
}

/// Data model for rendering a product card.
///
/// This is the UI-facing subset of the API [Product] schema.
class HaulProductCardData {
  const HaulProductCardData({
    required this.id,
    required this.name,
    required this.price,
    this.salePrice,
    this.imageUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.isNew = false,
    this.isSale = false,
    this.isOutOfStock = false,
    this.isWishlisted = false,
    this.matchScore,
    this.matchSourceLabel,
    this.category,
  });

  final String id;
  final String name;
  final double price;
  final double? salePrice;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final bool isNew;
  final bool isSale;
  final bool isOutOfStock;
  final bool isWishlisted;

  /// Visual search match score (0–1). Non-null means show match badge.
  final double? matchScore;
  final String? matchSourceLabel;
  final String? category;
}

/// The main product card widget used across all catalog surfaces.
///
/// Supports grid and horizontal variants, plus all state combinations:
/// normal, sale, new, out of stock, wishlisted, and visual-search-result
/// with match badge.
class HaulProductCard extends ConsumerStatefulWidget {
  const HaulProductCard({
    super.key,
    required this.data,
    this.variant = HaulCardVariant.grid,
    this.heroTag,
    this.onTap,
    this.onWishlistToggle,
    this.onAddToCart,
  });

  final HaulProductCardData data;
  final HaulCardVariant variant;
  final String? heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onWishlistToggle;
  final VoidCallback? onAddToCart;

  @override
  ConsumerState<HaulProductCard> createState() => _HaulProductCardState();
}

class _HaulProductCardState extends ConsumerState<HaulProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppMotion.durationFast,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: AppMotion.curveSpring),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleController.forward();
  void _onTapUp(TapUpDetails _) => _scaleController.reverse();
  void _onTapCancel() => _scaleController.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Hero(
          tag: widget.heroTag ?? AppMotion.productCardHero(widget.data.id),
          child: widget.variant == HaulCardVariant.horizontal
              ? _buildHorizontal()
              : _buildGrid(),
        ),
      ),
    );
  }

  // ── Grid variant ─────────────────────────────────────────────────────

  Widget _buildGrid() {
    final data = widget.data;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          _buildImageSection(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.card),
              topRight: Radius.circular(AppRadius.card),
            ),
            aspectRatio: 1.0,
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  data.name,
                  style: AppTypography.bodySmallMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Category
                if (data.category != null)
                  Text(data.category!, style: AppTypography.caption),
                const SizedBox(height: AppSpacing.xs),
                // Price row
                _buildPriceRow(),
                const SizedBox(height: AppSpacing.xs),
                // Rating row
                if (data.rating > 0) _buildRatingRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Horizontal variant ───────────────────────────────────────────────

  Widget _buildHorizontal() {
    final data = widget.data;
    return Container(
      height: 120,
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Image on left
          SizedBox(
            width: 120,
            child: _buildImageSection(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card),
                bottomLeft: Radius.circular(AppRadius.card),
              ),
            ),
          ),
          // Info on right
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.name,
                    style: AppTypography.bodySmallMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _buildPriceRow(),
                  if (data.rating > 0) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    _buildRatingRow(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared sub-components ────────────────────────────────────────────

  Widget _buildImageSection({
    required BorderRadius borderRadius,
    double? aspectRatio,
  }) {
    final data = widget.data;
    Widget imageWidget = ClipRRect(
      borderRadius: borderRadius,
      child: data.imageUrl != null
          ? Image.network(
              data.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) =>
                  _buildImagePlaceholder(),
            )
          : _buildImagePlaceholder(),
    );

    Widget stack = Stack(
      fit: StackFit.passthrough,
      children: [
        if (aspectRatio != null)
          AspectRatio(aspectRatio: aspectRatio, child: imageWidget)
        else
          Positioned.fill(child: imageWidget),

        // Out of stock overlay
        if (data.isOutOfStock)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Container(
                color: AppColors.outOfStockOverlay,
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: AppRadius.chipBorderRadius,
                  ),
                  child: Text(
                    'Out of Stock',
                    style: AppTypography.captionMedium.copyWith(
                      color: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Badges (top-left)
        Positioned(
          top: AppSpacing.xs,
          left: AppSpacing.xs,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.isSale) _buildBadge('Sale', AppColors.accent),
              if (data.isNew)
                Padding(
                  padding: data.isSale
                      ? const EdgeInsets.only(top: AppSpacing.xxs)
                      : EdgeInsets.zero,
                  child: _buildBadge('New', AppColors.newBadge),
                ),
              if (data.matchScore != null)
                Padding(
                  padding: EdgeInsets.only(
                    top: (data.isSale || data.isNew) ? 4 : 0,
                  ),
                  child: _buildMatchBadge(data.matchScore!),
                ),
            ],
          ),
        ),

        // Wishlist heart (top-right)
        Positioned(
          top: AppSpacing.xs,
          right: AppSpacing.xs,
          child: _buildWishlistButton(),
        ),

        // AI badge (bottom-left, if match score exists)
        if (data.matchScore != null)
          Positioned(
            bottom: AppSpacing.xs,
            left: AppSpacing.xs,
            child: data.matchSourceLabel == null
                ? const HaulAiBadge(compact: true)
                : HaulAiBadge(label: data.matchSourceLabel!),
          ),
      ],
    );

    if (aspectRatio != null) {
      return stack;
    }
    return stack;
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.border,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textSecondary.withValues(alpha: 0.4),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.chipBorderRadius,
      ),
      child: Text(
        label,
        style: AppTypography.micro.copyWith(color: AppColors.surface),
      ),
    );
  }

  Widget _buildMatchBadge(double score) {
    final percent = (score * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.9),
        borderRadius: AppRadius.chipBorderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 10, color: AppColors.surface),
          const SizedBox(width: AppSpacing.micro),
          Text(
            '$percent% match',
            style: AppTypography.micro.copyWith(color: AppColors.surface),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistButton() {
    final wishlistedState = ref.watch(wishlistControllerProvider);
    final wishlisted =
        wishlistedState.value?.contains(widget.data.id) ??
        widget.data.isWishlisted;

    return GestureDetector(
      onTap: () {
        if (widget.onWishlistToggle != null) {
          widget.onWishlistToggle!();
        } else {
          ref
              .read(wishlistControllerProvider.notifier)
              .toggleWishlist(widget.data.id);
        }
      },
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveSpring,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: AppShadows.button,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: AppMotion.durationFast,
            child: Icon(
              wishlisted ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(wishlisted),
              size: 18,
              color: wishlisted ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow() {
    final data = widget.data;
    if (data.isSale && data.salePrice != null) {
      return Row(
        children: [
          Text(
            '\$${data.salePrice!.toStringAsFixed(0)}',
            style: AppTypography.priceSale,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '\$${data.price.toStringAsFixed(0)}',
            style: AppTypography.priceOriginalStrikethrough,
          ),
        ],
      );
    }
    return Text(
      '\$${data.price.toStringAsFixed(0)}',
      style: AppTypography.priceRegular,
    );
  }

  Widget _buildRatingRow() {
    final data = widget.data;
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
        const SizedBox(width: AppSpacing.micro),
        Text(
          data.rating.toStringAsFixed(1),
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text('(${data.reviewCount})', style: AppTypography.caption),
      ],
    );
  }
}
