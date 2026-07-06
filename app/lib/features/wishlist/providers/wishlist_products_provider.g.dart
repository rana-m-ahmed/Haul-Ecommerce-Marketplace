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

String _$wishlistProductsHash() => r'c3510b0284d6a0b044f6a8a8313889f0c0813602';

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

String _$wishlistPreviewHash() => r'4bbf945e862c025b6cecea3d5620cff109842edc';
