import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import '../catalog/catalog_ui.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forYou = ref.watch(forYouProductsProvider);
    final grid = ref.watch(homeGridProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const _CameraPulseFab(),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(forYouProductsProvider);
            ref.invalidate(homeGridProductsProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _HomeAppBar(),
                      AppSpacing.gapLg,
                      const _SearchEntry(),
                      AppSpacing.gapLg,
                      _SectionHeader(
                        title: 'For You',
                        actionLabel: forYou.when(
                          data: (value) => value.fallbackUsed
                              ? 'Trending'
                              : 'Personalized',
                          loading: () => 'Finding signals',
                          error: (_, _) => 'Trending',
                        ),
                        onAction: () => context.go('/search'),
                      ),
                      AppSpacing.gapSm,
                      _ForYouRail(recommendations: forYou),
                      AppSpacing.gapLg,
                      const _CategoryRail(),
                      AppSpacing.gapLg,
                      const _FeaturedBanner(),
                      AppSpacing.gapLg,
                      _SectionHeader(
                        title: 'Trending',
                        actionLabel: 'See all',
                        onAction: () => context.go('/search'),
                      ),
                    ],
                  ),
                ),
              ),
              _TrendingGrid(products: grid),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HAUL', style: AppTypography.captionMedium),
              Text('Find your next signal.', style: AppTypography.h1),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.person_outline_rounded),
          color: AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/search'),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.buttonBorderRadius,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.textSecondary),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                'Search products, colors, styles',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Icon(Icons.tune_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.h2)),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: AppTypography.captionMedium.copyWith(
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _ForYouRail extends StatelessWidget {
  const _ForYouRail({required this.recommendations});

  final AsyncValue<RecommendationsResponse> recommendations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: recommendations.when(
        data: (response) {
          final items = response.products;
          if (items.isEmpty) {
            return const _CompactMessage('Fresh picks are warming up.');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.take(6).length,
            separatorBuilder: (context, index) => AppSpacing.hGapMd,
            itemBuilder: (context, index) {
              final product = items[index];
              final heroTag = AppMotion.heroTag(
                'product_card_rail',
                product.id,
              );
              return StaggeredListItem(
                index: index,
                direction: AxisDirection.right,
                child: HaulProductCard(
                  data: product.toCardData(),
                  variant: HaulCardVariant.horizontal,
                  heroTag: heroTag,
                  onTap: () => context.push(
                    '/products/${product.id}',
                    extra: ProductRouteExtra(
                      product: product,
                      heroTag: heroTag,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (context, index) => AppSpacing.hGapMd,
          itemBuilder: (context, index) => const SizedBox(
            width: 280,
            child: HaulSkeleton(width: 280, height: 120),
          ),
        ),
        error: (error, stackTrace) =>
            const _CompactMessage('Fresh picks are warming up.'),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.xxl,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ProductCategory.values.length,
        separatorBuilder: (context, index) => AppSpacing.hGapSm,
        itemBuilder: (context, index) {
          final category = ProductCategory.values[index];
          return ActionChip(
            avatar: Icon(_categoryIcon(category), size: 18),
            label: Text(category.label),
            onPressed: () => context.go('/search?category=${category.name}'),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.border),
            labelStyle: AppTypography.bodySmallMedium,
          );
        },
      ),
    );
  }

  IconData _categoryIcon(ProductCategory category) {
    return switch (category) {
      ProductCategory.fashion => Icons.checkroom_rounded,
      ProductCategory.electronics => Icons.devices_rounded,
      ProductCategory.home => Icons.chair_rounded,
      ProductCategory.skincare => Icons.spa_rounded,
      ProductCategory.fitness => Icons.fitness_center_rounded,
      ProductCategory.accessories => Icons.watch_rounded,
    };
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fresh signals',
                  style: AppTypography.captionMedium.copyWith(
                    color: AppColors.accentSoft,
                  ),
                ),
                AppSpacing.gapXs,
                Text(
                  'New arrivals across home, fitness, and accessories.',
                  style: AppTypography.h2.copyWith(color: AppColors.surface),
                ),
              ],
            ),
          ),
          AppSpacing.hGapMd,
          Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.accentSoft,
            size: 40,
          ),
        ],
      ),
    );
  }
}

class _TrendingGrid extends StatelessWidget {
  const _TrendingGrid({required this.products});

  final AsyncValue<List<Product>> products;

  @override
  Widget build(BuildContext context) {
    return products.when(
      data: (items) {
        if (items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: HaulEmptyState(
              title: 'No products yet',
              subtitle: 'Try another category or come back soon.',
              actionLabel: 'Browse search',
              onAction: () => context.go('/search'),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverGrid.builder(
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.5,
            ),
            itemBuilder: (context, index) {
              final product = items[index];
              final heroTag = AppMotion.productCardHero(product.id);
              return StaggeredListItem(
                index: index,
                child: HaulProductCard(
                  data: product.toCardData(),
                  heroTag: heroTag,
                  onTap: () => context.push(
                    '/products/${product.id}',
                    extra: ProductRouteExtra(
                      product: product,
                      heroTag: heroTag,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverGrid.builder(
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.5,
          ),
          itemBuilder: (context, index) => HaulSkeleton.productCard(),
        ),
      ),
      error: (error, stackTrace) => SliverFillRemaining(
        hasScrollBody: false,
        child: HaulErrorState(
          subtitle: 'Could not load trending products.',
          onRetry: () {},
        ),
      ),
    );
  }
}

class _CompactMessage extends StatelessWidget {
  const _CompactMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _CameraPulseFab extends StatefulWidget {
  const _CameraPulseFab();

  @override
  State<_CameraPulseFab> createState() => _CameraPulseFabState();
}

class _CameraPulseFabState extends State<_CameraPulseFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationSlow,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.curveSpring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: FloatingActionButton(
        heroTag: 'camera_fab',
        onPressed: () => context.push('/camera'),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.surface,
        child: const Icon(Icons.photo_camera_rounded),
      ),
    );
  }
}
