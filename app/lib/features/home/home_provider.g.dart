// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trendingProducts)
final trendingProductsProvider = TrendingProductsProvider._();

final class TrendingProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  TrendingProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendingProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendingProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return trendingProducts(ref);
  }
}

String _$trendingProductsHash() => r'826540094500b6eff2be047c3f4f5b0dd0e36a22';

@ProviderFor(homeGridProducts)
final homeGridProductsProvider = HomeGridProductsProvider._();

final class HomeGridProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  HomeGridProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeGridProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeGridProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return homeGridProducts(ref);
  }
}

String _$homeGridProductsHash() => r'9388381f231930784d51b847554cc0d393b0bf4e';
