// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orders_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(orders)
final ordersProvider = OrdersProvider._();

final class OrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<OrdersResponse>,
          OrdersResponse,
          FutureOr<OrdersResponse>
        >
    with $FutureModifier<OrdersResponse>, $FutureProvider<OrdersResponse> {
  OrdersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ordersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ordersHash();

  @$internal
  @override
  $FutureProviderElement<OrdersResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OrdersResponse> create(Ref ref) {
    return orders(ref);
  }
}

String _$ordersHash() => r'014e5e9c6c56534137a34a83f5af38865532bff5';
