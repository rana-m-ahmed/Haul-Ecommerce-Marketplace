import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/cart_item.dart';
import 'cart_repository.dart';

part 'cart_controller.g.dart';

@riverpod
class CartController extends _$CartController {
  @override
  Future<List<CartItem>> build() async {
    final authState = ref.watch(authControllerProvider);

    final uid = switch (authState) {
      AuthStateAuthenticated(:final uid) => uid,
      AuthStateGuest() => FirebaseAuth.instance.currentUser?.uid,
      _ => null,
    };
    if (uid != null) {
      final repo = ref.read(cartRepositoryProvider);
      final cache = await repo.getCachedCart(uid);

      // Async fetch from firestore without awaiting in build
      _fetchFirestore(uid);
      return cache;
    }

    return [];
  }

  Future<void> _fetchFirestore(String uid) async {
    try {
      final repo = ref.read(cartRepositoryProvider);
      final items = await repo.fetchFirestoreCart(uid);
      state = AsyncData(items);
      await repo.saveCachedCart(uid, items);
    } catch (e) {
      // ignore or log
    }
  }

  Future<void> addItem(CartItem item) async {
    final authState = ref.read(authControllerProvider);
    final uid = _uid(authState);
    if (uid == null) return;
    final repo = ref.read(cartRepositoryProvider);
    final previousState = state;

    // Optimistic update
    final currentItems = state.value ?? [];
    final existingIndex = currentItems.indexWhere(
      (e) => e.productId == item.productId,
    );

    final newItems = List<CartItem>.from(currentItems);
    if (existingIndex >= 0) {
      final existing = newItems[existingIndex];
      newItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
      );
    } else {
      newItems.add(item);
    }

    state = AsyncData(newItems);
    await repo.saveCachedCart(uid, newItems);

    try {
      await repo.updateCartItem(
        uid,
        existingIndex >= 0 ? newItems[existingIndex] : item,
      );
    } catch (e) {
      // Rollback
      state = previousState;
      final prevItems = previousState.value ?? [];
      await repo.saveCachedCart(uid, prevItems);
      throw Exception('Failed to add item to cart: $e');
    }
  }

  Future<void> removeItem(String productId) async {
    final authState = ref.read(authControllerProvider);
    final uid = _uid(authState);
    if (uid == null) return;
    final repo = ref.read(cartRepositoryProvider);
    final previousState = state;

    // Optimistic update
    final currentItems = state.value ?? [];
    final newItems = currentItems
        .where((e) => e.productId != productId)
        .toList();

    state = AsyncData(newItems);
    await repo.saveCachedCart(uid, newItems);

    try {
      await repo.removeCartItem(uid, productId);
    } catch (e) {
      // Rollback
      state = previousState;
      final prevItems = previousState.value ?? [];
      await repo.saveCachedCart(uid, prevItems);
      throw Exception('Failed to remove item from cart: $e');
    }
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    final authState = ref.read(authControllerProvider);
    final uid = _uid(authState);
    if (uid == null) return;
    final repo = ref.read(cartRepositoryProvider);
    final previousState = state;

    // Optimistic update
    final currentItems = state.value ?? [];
    final existingIndex = currentItems.indexWhere(
      (e) => e.productId == productId,
    );
    if (existingIndex < 0) return;

    final newItems = List<CartItem>.from(currentItems);
    newItems[existingIndex] = newItems[existingIndex].copyWith(
      quantity: quantity,
    );

    state = AsyncData(newItems);
    await repo.saveCachedCart(uid, newItems);

    try {
      await repo.updateCartItem(uid, newItems[existingIndex]);
    } catch (e) {
      // Rollback
      state = previousState;
      final prevItems = previousState.value ?? [];
      await repo.saveCachedCart(uid, prevItems);
      throw Exception('Failed to update quantity: $e');
    }
  }

  String? _uid(AuthState authState) => switch (authState) {
    AuthStateAuthenticated(:final uid) => uid,
    AuthStateGuest() => FirebaseAuth.instance.currentUser?.uid,
    _ => null,
  };
}
