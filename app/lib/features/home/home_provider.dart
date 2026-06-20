import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';

part 'home_provider.g.dart';

final forYouProductsProvider = FutureProvider<RecommendationsResponse>((ref) async {
  final client = ref.watch(apiClientProvider);
  final auth = ref.watch(authControllerProvider);
  if (auth is AuthStateAuthenticated) {
    try {
      return await client.getRecommendations(auth.uid);
    } catch (_) {
      // The For You rail must always remain useful during backend wake-ups.
    }
  }
  final trending = await client.searchProducts(
    const SearchRequest(sortBy: ProductSort.rating, pageSize: 8),
  );
  return RecommendationsResponse(
    products: trending.products,
    fallbackUsed: true,
    reason: 'trending',
  );
});

@riverpod
FutureOr<List<Product>> trendingProducts(Ref ref) async {
  final response = await ref.watch(apiClientProvider).searchProducts(
    const SearchRequest(sortBy: ProductSort.rating, pageSize: 10),
  );
  return response.products;
}

@riverpod
FutureOr<List<Product>> homeGridProducts(Ref ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.searchProducts(
    const SearchRequest(sortBy: ProductSort.newest, pageSize: 24),
  );
  return response.products;
}
