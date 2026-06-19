import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'wishlist_repository.g.dart';

@riverpod
WishlistRepository wishlistRepository(Ref ref) {
  return WishlistRepository(FirebaseFirestore.instance);
}

class WishlistRepository {
  WishlistRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const _cacheKeyPrefix = 'wishlist_cache_';

  Future<List<String>> getCachedWishlist(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_cacheKeyPrefix$uid');
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<String>();
    }
    return [];
  }

  Future<void> saveCachedWishlist(String uid, List<String> productIds) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(productIds);
    await prefs.setString('$_cacheKeyPrefix$uid', encoded);
  }

  Future<List<String>> fetchFirestoreWishlist(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).collection('wishlist').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> addWishlistItem(String uid, String productId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .doc(productId)
        .set({'addedAt': FieldValue.serverTimestamp()});
  }

  Future<void> removeWishlistItem(String uid, String productId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .doc(productId)
        .delete();
  }
}
