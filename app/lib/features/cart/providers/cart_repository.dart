import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';

part 'cart_repository.g.dart';

@riverpod
CartRepository cartRepository(Ref ref) {
  return CartRepository(FirebaseFirestore.instance);
}

class CartRepository {
  CartRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const _cacheKeyPrefix = 'cart_cache_';

  Future<List<CartItem>> getCachedCart(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_cacheKeyPrefix$uid');
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> saveCachedCart(String uid, List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString('$_cacheKeyPrefix$uid', encoded);
  }

  Future<void> clearCachedCart(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cacheKeyPrefix$uid');
  }

  Future<List<CartItem>> fetchFirestoreCart(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).collection('cart').get();
    return snapshot.docs.map((doc) => CartItem.fromJson(doc.data())).toList();
  }

  Future<void> updateCartItem(String uid, CartItem item) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc(item.productId)
        .set(item.toJson(), SetOptions(merge: true));
  }

  Future<void> removeCartItem(String uid, String productId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc(productId)
        .delete();
  }
}
