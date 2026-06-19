import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'user_repository.dart';

part 'auth_provider.g.dart';

sealed class AuthState {
  const AuthState();
}

class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

class AuthStateGuest extends AuthState {
  const AuthStateGuest();
}

class AuthStateNewUser extends AuthState {
  final String uid;
  const AuthStateNewUser(this.uid);
}

class AuthStateAuthenticated extends AuthState {
  final String uid;
  const AuthStateAuthenticated(this.uid);
}

@riverpod
class AuthController extends _$AuthController {
  StreamSubscription<User?>? _sub;

  @override
  AuthState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });

    _sub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        state = const AuthStateUnauthenticated();
      } else {
        try {
          final repo = ref.read(userRepositoryProvider);
          final userProfile = await repo.getOrCreateUser(user);

          if (userProfile.isGuest) {
            state = const AuthStateGuest();
          } else if (!userProfile.preferencesCompleted) {
            state = AuthStateNewUser(user.uid);
          } else {
            state = AuthStateAuthenticated(user.uid);
          }
        } catch (e) {
          // If Firestore fails, gracefully drop them back to unauthenticated
          state = const AuthStateUnauthenticated();
        }
      }
    });

    return const AuthStateLoading();
  }

  Future<void> loginAsGuest() async {
    state = const AuthStateLoading();
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      state = const AuthStateUnauthenticated();
      rethrow;
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final hasPassword = password.trim().isNotEmpty;
    if (normalizedEmail.isEmpty || !hasPassword) {
      return;
    }

    state = const AuthStateLoading();
    try {
      // Try signing in first
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // If they don't exist, try creating them
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      state = const AuthStateUnauthenticated();
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    state = const AuthStateLoading();
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = const AuthStateUnauthenticated();
        return;
      }
      
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      state = const AuthStateUnauthenticated();
      rethrow;
    }
  }

  Future<void> completePreferences(List<String> categories) async {
    if (state is AuthStateNewUser) {
      final uid = (state as AuthStateNewUser).uid;
      state = const AuthStateLoading();
      try {
        await ref.read(userRepositoryProvider).updatePreferences(uid, categories);
        state = AuthStateAuthenticated(uid);
      } catch (e) {
        state = AuthStateNewUser(uid);
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    state = const AuthStateLoading();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }
}
