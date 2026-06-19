import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api/api_client.dart';

part 'search_provider.g.dart';

class SearchState {
  const SearchState({
    required this.products,
    required this.total,
    required this.hasMore,
    this.query = '',
    this.category,
    this.sortBy = ProductSort.relevance,
    this.minPrice,
    this.maxPrice,
    this.pageToken,
  });

  const SearchState.empty()
    : products = const [],
      total = 0,
      hasMore = false,
      query = '',
      category = null,
      sortBy = ProductSort.relevance,
      minPrice = null,
      maxPrice = null,
      pageToken = null;

  final List<Product> products;
  final int total;
  final bool hasMore;
  final String query;
  final ProductCategory? category;
  final ProductSort sortBy;
  final double? minPrice;
  final double? maxPrice;
  final String? pageToken;

  SearchState copyWith({
    List<Product>? products,
    int? total,
    bool? hasMore,
    String? query,
    ProductCategory? category,
    ProductSort? sortBy,
    double? minPrice,
    double? maxPrice,
    String? pageToken,
    bool clearCategory = false,
    bool clearPrice = false,
    bool clearPageToken = false,
  }) {
    return SearchState(
      products: products ?? this.products,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      query: query ?? this.query,
      category: clearCategory ? null : category ?? this.category,
      sortBy: sortBy ?? this.sortBy,
      minPrice: clearPrice ? null : minPrice ?? this.minPrice,
      maxPrice: clearPrice ? null : maxPrice ?? this.maxPrice,
      pageToken: clearPageToken ? null : pageToken ?? this.pageToken,
    );
  }

  bool get hasFilters =>
      category != null || minPrice != null || maxPrice != null;
}

@riverpod
class SearchNotifier extends _$SearchNotifier {
  @override
  FutureOr<SearchState> build() async {
    final response = await ref
        .watch(apiClientProvider)
        .searchProducts(const SearchRequest(pageSize: 24));
    return SearchState(
      products: response.products,
      total: response.total,
      hasMore: response.pageToken != null,
      pageToken: response.pageToken,
    );
  }

  Future<void> search({
    String? query,
    ProductCategory? category,
    ProductSort? sortBy,
    double? minPrice,
    double? maxPrice,
    bool clearCategory = false,
    bool clearPrice = false,
  }) async {
    final previous = state.value ?? const SearchState.empty();
    final nextQuery = query ?? previous.query;
    final nextCategory = clearCategory ? null : category ?? previous.category;
    final nextSort = sortBy ?? previous.sortBy;
    final nextMinPrice = clearPrice ? null : minPrice ?? previous.minPrice;
    final nextMaxPrice = clearPrice ? null : maxPrice ?? previous.maxPrice;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await ref
          .read(apiClientProvider)
          .searchProducts(
            SearchRequest(
              query: nextQuery.isEmpty ? null : nextQuery,
              category: nextCategory,
              minPrice: nextMinPrice,
              maxPrice: nextMaxPrice,
              sortBy: nextSort,
              pageSize: 24,
            ),
          );
      if (nextQuery.trim().isNotEmpty) {
        ref.read(recentSearchesProvider.notifier).add(nextQuery);
      }
      return SearchState(
        products: response.products,
        total: response.total,
        hasMore: response.pageToken != null,
        query: nextQuery,
        category: nextCategory,
        sortBy: nextSort,
        minPrice: nextMinPrice,
        maxPrice: nextMaxPrice,
        pageToken: response.pageToken,
      );
    });
  }

  Future<void> clearFilters() {
    final previous = state.value ?? const SearchState.empty();
    return search(
      query: previous.query,
      sortBy: previous.sortBy,
      clearCategory: true,
      clearPrice: true,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.pageToken == null) {
      return;
    }

    state = await AsyncValue.guard(() async {
      final response = await ref
          .read(apiClientProvider)
          .searchProducts(
            SearchRequest(
              query: current.query.isEmpty ? null : current.query,
              category: current.category,
              minPrice: current.minPrice,
              maxPrice: current.maxPrice,
              sortBy: current.sortBy,
              pageSize: 24,
              pageToken: current.pageToken,
            ),
          );
      return current.copyWith(
        products: [...current.products, ...response.products],
        total: response.total,
        hasMore: response.pageToken != null,
        pageToken: response.pageToken,
      );
    });
  }
}

@riverpod
class RecentSearches extends _$RecentSearches {
  @override
  List<String> build() => const [];

  void add(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }

    state = [
      normalized,
      ...state.where((item) => item.toLowerCase() != normalized.toLowerCase()),
    ].take(8).toList(growable: false);
  }

  void clear() {
    state = const [];
  }
}
