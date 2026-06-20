import 'package:flutter/material.dart';

import '../core/design/design.dart';
import '../shared/widgets/widgets.dart';

/// Dev-only widget gallery — visual QA tool for the Warm Signal design system.
///
/// Renders every shared widget in every state side by side.
/// Run this screen to visually verify all components.
class WidgetGallery extends StatelessWidget {
  const WidgetGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haul Widget Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      home: const _GalleryHome(),
    );
  }
}

class _GalleryHome extends StatelessWidget {
  const _GalleryHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Widget Gallery', style: AppTypography.h1),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined, color: AppColors.accent),
            onPressed: () {
              HaulBottomSheet.show(
                context: context,
                title: 'Design Tokens',
                builder: (_) => const _TokensPreview(),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _sectionTitle('Colors'),
          const _ColorSwatches(),
          AppSpacing.gapXl,

          _sectionTitle('Typography'),
          const _TypographyPreview(),
          AppSpacing.gapXl,

          _sectionTitle('Buttons'),
          const _ButtonsPreview(),
          AppSpacing.gapXl,

          _sectionTitle('AI Badge'),
          const _AiBadgePreview(),
          AppSpacing.gapXl,

          _sectionTitle('Product Cards — Grid'),
          const _ProductCardsGrid(),
          AppSpacing.gapXl,

          _sectionTitle('Product Cards — Horizontal'),
          const _ProductCardsHorizontal(),
          AppSpacing.gapXl,

          _sectionTitle('Skeleton Loaders'),
          const _SkeletonPreview(),
          AppSpacing.gapXl,

          _sectionTitle('Empty State'),
          const _EmptyStatePreview(),
          AppSpacing.gapXl,

          _sectionTitle('Error State'),
          const _ErrorStatePreview(),
          AppSpacing.gapXl,

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(title, style: AppTypography.h2),
    );
  }
}

// ── Color Swatches ─────────────────────────────────────────────────────

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches();

  @override
  Widget build(BuildContext context) {
    const colors = [
      ('background', AppColors.background),
      ('surface', AppColors.surface),
      ('textPrimary', AppColors.textPrimary),
      ('textSecondary', AppColors.textSecondary),
      ('accent', AppColors.accent),
      ('accentSoft', AppColors.accentSoft),
      ('success', AppColors.success),
      ('error', AppColors.error),
      ('border', AppColors.border),
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: colors.map((entry) {
        final (name, color) = entry;
        final isLight = color.computeLuminance() > 0.5;
        return Container(
          width: 100,
          height: 72,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.buttonBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.xs),
          alignment: Alignment.bottomLeft,
          child: Text(
            name,
            style: AppTypography.micro.copyWith(
              color: isLight ? AppColors.textPrimary : AppColors.surface,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Typography Preview ─────────────────────────────────────────────────

class _TypographyPreview extends StatelessWidget {
  const _TypographyPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Display Large (Syne 32)', style: AppTypography.displayLarge),
          AppSpacing.gapXs,
          Text('Display Small (Syne 28)', style: AppTypography.displaySmall),
          AppSpacing.gapXs,
          Text('Heading 1 (Syne 24)', style: AppTypography.h1),
          AppSpacing.gapXs,
          Text('Heading 2 (Syne 20)', style: AppTypography.h2),
          AppSpacing.gapXs,
          Text('Heading 3 (Syne 18)', style: AppTypography.h3),
          AppSpacing.gapXs,
          Text('Body Large (Inter 16)', style: AppTypography.bodyLarge),
          AppSpacing.gapXs,
          Text('Body Small (Inter 14)', style: AppTypography.bodySmall),
          AppSpacing.gapXs,
          Text('Caption (Inter 12)', style: AppTypography.caption),
          AppSpacing.gapXs,
          Row(
            children: [
              Text('\$89', style: AppTypography.priceSale),
              AppSpacing.hGapXs,
              Text('\$129', style: AppTypography.priceOriginalStrikethrough),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Buttons Preview ────────────────────────────────────────────────────

class _ButtonsPreview extends StatelessWidget {
  const _ButtonsPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary
          Text('Primary', style: AppTypography.captionMedium),
          AppSpacing.gapXs,
          Row(
            children: [
              HaulButton(label: 'Add to Cart', onPressed: () {}),
              AppSpacing.hGapXs,
              HaulButton(
                label: 'Buy',
                onPressed: () {},
                icon: const Icon(Icons.shopping_bag_outlined),
                size: HaulButtonSize.small,
              ),
            ],
          ),
          AppSpacing.gapMd,

          // Secondary
          Text('Secondary', style: AppTypography.captionMedium),
          AppSpacing.gapXs,
          Row(
            children: [
              HaulButton(
                label: 'View Details',
                onPressed: () {},
                variant: HaulButtonVariant.secondary,
              ),
              AppSpacing.hGapXs,
              HaulButton(
                label: 'Log out',
                icon: const Icon(Icons.logout_rounded),
                variant: HaulButtonVariant.secondary,
                size: HaulButtonSize.small,
              ),
            ],
          ),
          AppSpacing.gapMd,

          // Text
          Text('Text', style: AppTypography.captionMedium),
          AppSpacing.gapXs,
          HaulButton(
            label: 'See All',
            onPressed: () {},
            variant: HaulButtonVariant.text,
          ),
          AppSpacing.gapMd,

          // Disabled + Loading
          Text('Disabled & Loading', style: AppTypography.captionMedium),
          AppSpacing.gapXs,
          Row(
            children: [
              const HaulButton(label: 'Disabled', onPressed: null),
              AppSpacing.hGapXs,
              HaulButton(label: 'Loading', onPressed: () {}, isLoading: true),
            ],
          ),
          AppSpacing.gapMd,

          // Full width
          Text('Full Width', style: AppTypography.captionMedium),
          AppSpacing.gapXs,
          HaulButton(
            label: 'Checkout',
            onPressed: () {},
            fullWidth: true,
            icon: const Icon(Icons.lock_outline_rounded),
          ),
        ],
      ),
    );
  }
}

// ── AI Badge Preview ───────────────────────────────────────────────────

class _AiBadgePreview extends StatelessWidget {
  const _AiBadgePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          const HaulAiBadge(),
          AppSpacing.hGapMd,
          const HaulAiBadge(label: 'For You'),
          AppSpacing.hGapMd,
          const HaulAiBadge(compact: true),
        ],
      ),
    );
  }
}

// ── Product Card Data Samples ──────────────────────────────────────────

final _sampleCards = <(String label, HaulProductCardData)>[
  (
    'Normal',
    const HaulProductCardData(
      id: 'p001',
      name: 'Minimalist Leather Tote',
      price: 89,
      imageUrl: null,
      rating: 4.5,
      reviewCount: 128,
      category: 'fashion',
    ),
  ),
  (
    'Sale',
    const HaulProductCardData(
      id: 'p002',
      name: 'Cloudlift Training Sneaker',
      price: 88,
      salePrice: 74,
      imageUrl: null,
      rating: 4.6,
      reviewCount: 144,
      isSale: true,
      category: 'fitness',
    ),
  ),
  (
    'New',
    const HaulProductCardData(
      id: 'p003',
      name: 'Arc Ceramic Table Lamp',
      price: 64,
      imageUrl: null,
      rating: 4.7,
      reviewCount: 91,
      isNew: true,
      category: 'home',
    ),
  ),
  (
    'Out of Stock',
    const HaulProductCardData(
      id: 'p004',
      name: 'Glow Serum Set',
      price: 42,
      imageUrl: null,
      rating: 4.8,
      reviewCount: 203,
      isOutOfStock: true,
      category: 'skincare',
    ),
  ),
  (
    'Wishlisted',
    const HaulProductCardData(
      id: 'p005',
      name: 'Ember Wireless Speaker',
      price: 56,
      imageUrl: null,
      rating: 4.3,
      reviewCount: 87,
      isWishlisted: true,
      category: 'electronics',
    ),
  ),
  (
    'Visual Search Match',
    const HaulProductCardData(
      id: 'p006',
      name: 'Linen Wrapped Candle',
      price: 24,
      imageUrl: null,
      rating: 4.9,
      reviewCount: 312,
      matchScore: 0.91,
      category: 'home',
    ),
  ),
  (
    'Sale + New + Wishlisted',
    const HaulProductCardData(
      id: 'p007',
      name: 'Adjustable Resistance Band Set',
      price: 34,
      salePrice: 28,
      imageUrl: null,
      rating: 4.4,
      reviewCount: 67,
      isSale: true,
      isNew: true,
      isWishlisted: true,
      category: 'fitness',
    ),
  ),
  (
    'Match + Out of Stock',
    const HaulProductCardData(
      id: 'p008',
      name: 'Titanium Travel Mug',
      price: 45,
      imageUrl: null,
      rating: 4.1,
      reviewCount: 56,
      isOutOfStock: true,
      matchScore: 0.73,
      category: 'accessories',
    ),
  ),
];

// ── Product Cards Grid ─────────────────────────────────────────────────

class _ProductCardsGrid extends StatelessWidget {
  const _ProductCardsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _sampleCards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sampleCards[i].$1,
                        style: AppTypography.captionMedium,
                      ),
                      AppSpacing.gapXxs,
                      HaulProductCard(
                        data: _sampleCards[i].$2,
                        onTap: () {},
                        onWishlistToggle: () {},
                      ),
                    ],
                  ),
                ),
                AppSpacing.hGapSm,
                if (i + 1 < _sampleCards.length)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sampleCards[i + 1].$1,
                          style: AppTypography.captionMedium,
                        ),
                        AppSpacing.gapXxs,
                        HaulProductCard(
                          data: _sampleCards[i + 1].$2,
                          onTap: () {},
                          onWishlistToggle: () {},
                        ),
                      ],
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Product Cards Horizontal ───────────────────────────────────────────

class _ProductCardsHorizontal extends StatelessWidget {
  const _ProductCardsHorizontal();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sampleCards.length,
        separatorBuilder: (context, index) => AppSpacing.hGapSm,
        itemBuilder: (_, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_sampleCards[index].$1, style: AppTypography.caption),
              AppSpacing.gapXxs,
              Expanded(
                child: HaulProductCard(
                  data: _sampleCards[index].$2,
                  variant: HaulCardVariant.horizontal,
                  onTap: () {},
                  onWishlistToggle: () {},
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Skeleton Preview ───────────────────────────────────────────────────

class _SkeletonPreview extends StatelessWidget {
  const _SkeletonPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grid Card Skeleton', style: AppTypography.captionMedium),
        AppSpacing.gapXs,
        Row(
          children: [
            Expanded(child: HaulSkeleton.productCard()),
            AppSpacing.hGapSm,
            Expanded(child: HaulSkeleton.productCard()),
          ],
        ),
        AppSpacing.gapMd,
        Text('Horizontal Card Skeleton', style: AppTypography.captionMedium),
        AppSpacing.gapXs,
        HaulSkeleton.productCardHorizontal(),
        AppSpacing.gapMd,
        Text('Generic Shapes', style: AppTypography.captionMedium),
        AppSpacing.gapXs,
        Row(
          children: [
            HaulSkeleton.rect(width: 80, height: 14),
            AppSpacing.hGapXs,
            HaulSkeleton.rect(width: 120, height: 14),
            AppSpacing.hGapXs,
            HaulSkeleton.circle(diameter: 40),
          ],
        ),
      ],
    );
  }
}

// ── Empty State Preview ────────────────────────────────────────────────

class _EmptyStatePreview extends StatelessWidget {
  const _EmptyStatePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: HaulEmptyState(
        title: 'Your cart is empty',
        subtitle: 'Browse our collection and find something you love.',
        actionLabel: 'Start Shopping',
        onAction: () {},
      ),
    );
  }
}

// ── Error State Preview ────────────────────────────────────────────────

class _ErrorStatePreview extends StatelessWidget {
  const _ErrorStatePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: HaulErrorState(
        title: 'Couldn\'t load products',
        subtitle: 'Check your connection and try again.',
        onRetry: () {},
      ),
    );
  }
}

// ── Tokens Bottom Sheet ────────────────────────────────────────────────

class _TokensPreview extends StatelessWidget {
  const _TokensPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spacing Scale', style: AppTypography.h3),
          AppSpacing.gapSm,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [4, 8, 12, 16, 24, 32, 48, 64].map((s) {
              return Container(
                width: s.toDouble(),
                height: s.toDouble(),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.micro),
                  border: Border.all(color: AppColors.accent, width: 1),
                ),
              );
            }).toList(),
          ),
          AppSpacing.gapLg,
          Text('Border Radius', style: AppTypography.h3),
          AppSpacing.gapSm,
          Row(
            children: [
              _radiusBox('Card: 20', AppRadius.card),
              AppSpacing.hGapXs,
              _radiusBox('Button: 14', AppRadius.button),
              AppSpacing.hGapXs,
              _radiusBox('Sheet: 28', AppRadius.bottomSheet),
            ],
          ),
          AppSpacing.gapLg,
        ],
      ),
    );
  }

  Widget _radiusBox(String label, double radius) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        AppSpacing.gapXxs,
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
