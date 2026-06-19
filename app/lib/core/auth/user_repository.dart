import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'models/user_profile.dart';

part 'user_repository.g.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference get _users => _firestore.collection('users');

  Future<UserProfile> getOrCreateUser(User firebaseUser) async {
    final docRef = _users.doc(firebaseUser.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      final updatedDoc = await docRef.get();
      return UserProfile.fromFirestore(updatedDoc);
    } else {
      final now = DateTime.now();
      final newUser = UserProfile(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName,
        isGuest: firebaseUser.isAnonymous,
        preferences: [],
        preferencesCompleted: false,
        createdAt: now,
        lastActiveAt: now,
      );
      await docRef.set(newUser.toMap());
      return newUser;
    }
  }

  Future<void> updatePreferences(String uid, List<String> categories) async {
    await _users.doc(uid).update({
      'preferences': categories,
      'preferencesCompleted': true,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserProfile?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromFirestore(doc);
    }
    return null;
  }
}

@riverpod
UserRepository userRepository(Ref ref) {
  return UserRepository(FirebaseFirestore.instance);
}
