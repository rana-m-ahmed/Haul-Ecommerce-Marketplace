import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api/api_client.dart';

part 'product_provider.g.dart';

@riverpod
FutureOr<Product> productDetail(Ref ref, String id) {
  return ref.watch(apiClientProvider).getProduct(id);
}

final productExplanationProvider = FutureProvider.autoDispose
    .family<ExplainProductResponse, ({String uid, String productId})>((
      ref,
      request,
    ) {
      return ref.watch(apiClientProvider).explainProduct(
        uid: request.uid,
        productId: request.productId,
      );
    });
