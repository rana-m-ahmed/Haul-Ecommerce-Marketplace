// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WishlistController)
final wishlistControllerProvider = WishlistControllerProvider._();

final class WishlistControllerProvider
    extends $AsyncNotifierProvider<WishlistController, List<String>> {
  WishlistControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wishlistControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wishlistControllerHash();

  @$internal
  @override
  WishlistController create() => WishlistController();
}

String _$wishlistControllerHash() =>
    r'f7cde27e0a994d5412d083c3cb6544956bb2442f';

abstract class _$WishlistController extends $AsyncNotifier<List<String>> {
  FutureOr<List<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<String>>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<String>>, List<String>>,
              AsyncValue<List<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
