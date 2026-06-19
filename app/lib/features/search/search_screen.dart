import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import '../catalog/catalog_ui.dart';
import 'search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialCategory});

  final ProductCategory? initialCategory;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _appliedInitialCategory = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_appliedInitialCategory && widget.initialCategory != null) {
      _appliedInitialCategory = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(searchProvider.notifier)
            .search(category: widget.initialCategory);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(AppMotion.durationSlow, () {
      ref
          .read(searchProvider.notifier)
          .search(query: _queryController.text.trim());
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - AppSpacing.xxxl) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final recents = ref.watch(recentSearchesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Search', style: AppTypography.h1)),
                      IconButton(
                        onPressed: _showFilterSheet,
                        icon: const Icon(Icons.tune_rounded),
                        color: AppColors.textPrimary,
                      ),
                      IconButton(
                        onPressed: _showSortSheet,
                        icon: const Icon(Icons.swap_vert_rounded),
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  AppSpacing.gapSm,
                  TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: 'Search lamp, tote, serum...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  if (recents.isNotEmpty) ...[
                    AppSpacing.gapSm,
                    _RecentSearches(
                      searches: recents,
                      onTap: (query) {
                        _queryController.text = query;
                        _queryController.selection = TextSelection.collapsed(
                          offset: query.length,
                        );
                        ref.read(searchProvider.notifier).search(query: query);
                      },
                      onClear: () =>
                          ref.read(recentSearchesProvider.notifier).clear(),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: search.when(
                data: _buildResults,
                loading: _buildLoading,
                error: (error, stackTrace) => HaulErrorState(
                  subtitle: 'Search could not load products.',
                  onRetry: () => ref.read(searchProvider.notifier).search(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    if (state.products.isEmpty) {
      return HaulEmptyState(
        title: 'No matches',
        subtitle: 'Try a different search, filter, or sort.',
        actionLabel: state.hasFilters ? 'Clear filters' : null,
        onAction: state.hasFilters
            ? () => ref.read(searchProvider.notifier).clearFilters()
            : null,
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(child: _ResultSummary(state: state)),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverGrid.builder(
            itemCount: state.products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.5,
            ),
            itemBuilder: (context, index) {
              final product = state.products[index];
              final heroTag = AppMotion.heroTag(
                'product_card_search',
                product.id,
              );
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
        ),
        if (state.hasMore)
          SliverPadding(
            padding: AppSpacing.paddingLg,
            sliver: SliverToBoxAdapter(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
      ],
    );
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: AppSpacing.paddingLg,
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.5,
      ),
      itemBuilder: (context, index) => HaulSkeleton.productCard(),
    );
  }

  void _showFilterSheet() {
    final current = ref.read(searchProvider).value ?? const SearchState.empty();
    ProductCategory? selectedCategory = current.category;
    double? minPrice = current.minPrice;
    double? maxPrice = current.maxPrice;

    HaulBottomSheet.show<void>(
      context: context,
      title: 'Filters',
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Category', style: AppTypography.h3),
                  AppSpacing.gapSm,
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: selectedCategory == null,
                        onSelected: (_) => setSheetState(() {
                          selectedCategory = null;
                        }),
                      ),
                      for (final category in ProductCategory.values)
                        ChoiceChip(
                          label: Text(category.label),
                          selected: selectedCategory == category,
                          onSelected: (_) => setSheetState(() {
                            selectedCategory = category;
                          }),
                        ),
                    ],
                  ),
                  AppSpacing.gapLg,
                  Text('Price', style: AppTypography.h3),
                  AppSpacing.gapSm,
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: const Text('Any'),
                        selected: minPrice == null && maxPrice == null,
                        onSelected: (_) => setSheetState(() {
                          minPrice = null;
                          maxPrice = null;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Under \$50'),
                        selected: minPrice == null && maxPrice == 50,
                        onSelected: (_) => setSheetState(() {
                          minPrice = null;
                          maxPrice = 50;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('\$50-\$100'),
                        selected: minPrice == 50 && maxPrice == 100,
                        onSelected: (_) => setSheetState(() {
                          minPrice = 50;
                          maxPrice = 100;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('\$100+'),
                        selected: minPrice == 100 && maxPrice == null,
                        onSelected: (_) => setSheetState(() {
                          minPrice = 100;
                          maxPrice = null;
                        }),
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,
                  Row(
                    children: [
                      Expanded(
                        child: HaulButton(
                          label: 'Reset',
                          variant: HaulButtonVariant.secondary,
                          onPressed: () {
                            Navigator.of(context).pop();
                            ref.read(searchProvider.notifier).clearFilters();
                          },
                        ),
                      ),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: HaulButton(
                          label: 'Apply',
                          onPressed: () {
                            Navigator.of(context).pop();
                            ref
                                .read(searchProvider.notifier)
                                .search(
                                  category: selectedCategory,
                                  minPrice: minPrice,
                                  maxPrice: maxPrice,
                                  clearCategory: selectedCategory == null,
                                  clearPrice:
                                      minPrice == null && maxPrice == null,
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSortSheet() {
    final current = ref.read(searchProvider).value ?? const SearchState.empty();
    HaulBottomSheet.show<void>(
      context: context,
      title: 'Sort',
      builder: (context) {
        return Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sort in ProductSort.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(sort.label, style: AppTypography.bodyLarge),
                  trailing: Icon(
                    current.sortBy == sort
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: current.sortBy == sort
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(searchProvider.notifier).search(sortBy: sort);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.searches,
    required this.onTap,
    required this.onClear,
  });

  final List<String> searches;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Recent', style: AppTypography.captionMedium)),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final query in searches)
              ActionChip(
                label: Text(query),
                onPressed: () => onTap(query),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.border),
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final filterLabel = state.category?.label ?? 'All categories';
    return Row(
      children: [
        Expanded(
          child: Text(
            '${state.total} results · $filterLabel',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(state.sortBy.label, style: AppTypography.captionMedium),
      ],
    );
  }
}
