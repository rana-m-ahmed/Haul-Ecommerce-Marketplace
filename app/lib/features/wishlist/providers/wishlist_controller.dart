import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/auth/auth_provider.dart';
import 'wishlist_repository.dart';

part 'wishlist_controller.g.dart';

@riverpod
class WishlistController extends _$WishlistController {
  @override
  Future<List<String>> build() async {
    final authState = ref.watch(authControllerProvider);

    if (authState is AuthStateAuthenticated || authState is AuthStateGuest) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final repo = ref.read(wishlistRepositoryProvider);
        final cache = await repo.getCachedWishlist(user.uid);

        // Async fetch from firestore
        _fetchFirestore(user.uid);
        return cache;
      }
    }

    return [];
  }

  Future<void> _fetchFirestore(String uid) async {
    try {
      final repo = ref.read(wishlistRepositoryProvider);
      final items = await repo.fetchFirestoreWishlist(uid);
      state = AsyncData(items);
      await repo.saveCachedWishlist(uid, items);
    } catch (e) {
      // ignore or log
    }
  }

  Future<void> toggleWishlist(String productId) async {
    final authState = ref.read(authControllerProvider);
    if (authState is! AuthStateAuthenticated && authState is! AuthStateGuest) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final uid = user.uid;
    final repo = ref.read(wishlistRepositoryProvider);
    final previousState = state;

    final currentItems = state.value ?? [];
    final isWishlisted = currentItems.contains(productId);

    final newItems = List<String>.from(currentItems);
    if (isWishlisted) {
      newItems.remove(productId);
    } else {
      newItems.add(productId);
    }

    // Optimistic update
    state = AsyncData(newItems);
    await repo.saveCachedWishlist(uid, newItems);

    try {
      if (isWishlisted) {
        await repo.removeWishlistItem(uid, productId);
      } else {
        await repo.addWishlistItem(uid, productId);
      }
    } catch (e) {
      // Rollback
      state = previousState;
      final prevItems = previousState.value ?? [];
      await repo.saveCachedWishlist(uid, prevItems);
      throw Exception('Failed to update wishlist: $e');
    }
  }
}
