import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import 'wishlist_controller.dart';

part 'wishlist_products_provider.g.dart';

@riverpod
Future<List<Product>> wishlistProducts(Ref ref) async {
  final itemIds = await ref.watch(wishlistControllerProvider.future);
  if (itemIds.isEmpty) return [];
  
  final client = ref.watch(apiClientProvider);
  
  // Since our API currently lacks batch fetch, we do them in parallel
  // Catch individual errors so one bad ID doesn't crash the whole wishlist
  final results = await Future.wait(
    itemIds.map((id) => client.getProduct(id).then<Product?>((p) => p).catchError((_) => null)),
  );
  
  return results.whereType<Product>().toList();
}

@riverpod
Future<List<Product>> wishlistPreview(Ref ref) async {
  final itemIds = await ref.watch(wishlistControllerProvider.future);
  if (itemIds.isEmpty) return [];
  
  final client = ref.watch(apiClientProvider);
  
  final results = await Future.wait(
    itemIds.take(4).map((id) => client.getProduct(id).then<Product?>((p) => p).catchError((_) => null)),
  );
  
  return results.whereType<Product>().toList();
}
