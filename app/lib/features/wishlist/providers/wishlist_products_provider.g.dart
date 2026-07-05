// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist_products_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(wishlistProducts)
final wishlistProductsProvider = WishlistProductsProvider._();

final class WishlistProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  WishlistProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wishlistProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wishlistProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return wishlistProducts(ref);
  }
}

String _$wishlistProductsHash() => r'ed17e9fee9d77b208a08d84f16d775cecb77f5dd';

@ProviderFor(wishlistPreview)
final wishlistPreviewProvider = WishlistPreviewProvider._();

final class WishlistPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  WishlistPreviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wishlistPreviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wishlistPreviewHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return wishlistPreview(ref);
  }
}

String _$wishlistPreviewHash() => r'5bb7749f4aa9eb7f52e5f8b2e15eb20d34d2b7c5';
