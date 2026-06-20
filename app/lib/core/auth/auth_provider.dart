import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/search/search_provider.dart';
import '../session/session_resource_registry.dart';
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
    if (normalizedEmail.isEmpty || password.isEmpty) return;

    state = const AuthStateLoading();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } catch (e) {
      state = const AuthStateUnauthenticated();
      rethrow;
    }
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty || username.trim().isEmpty) {
      return;
    }

    state = const AuthStateLoading();
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser?.isAnonymous ?? false) {
        final credential = EmailAuthProvider.credential(
          email: normalizedEmail,
          password: password,
        );
        final linked = await currentUser!.linkWithCredential(credential);
        final user = linked.user;
        if (user != null) {
          await user.updateDisplayName(username.trim());
          // Reload user to ensure displayName propagates
          await user.reload();
          await ref
              .read(userRepositoryProvider)
              .promoteGuest(user.uid, FirebaseAuth.instance.currentUser!);
          state = AuthStateAuthenticated(user.uid);
          return;
        }
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: normalizedEmail,
              password: password,
            );
        final user = credential.user;
        if (user != null) {
          await user.updateDisplayName(username.trim());
          await user.reload();
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.isAnonymous ?? false) {
        final linked = await currentUser!.linkWithCredential(credential);
        await ref
            .read(userRepositoryProvider)
            .promoteGuest(linked.user!.uid, linked.user!);
        state = AuthStateAuthenticated(linked.user!.uid);
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
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
        await ref
            .read(userRepositoryProvider)
            .updatePreferences(uid, categories);
        state = AuthStateAuthenticated(uid);
      } catch (e) {
        state = AuthStateNewUser(uid);
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    state = const AuthStateLoading();
    try {
      await const SessionCleaner().clear();
      ref.read(recentSearchesProvider.notifier).clear();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.isAnonymous) {
        await user.delete();
      } else {
        await FirebaseAuth.instance.signOut();
      }
      state = const AuthStateUnauthenticated();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Firebase owns the app session; Google cleanup must not undo logout.
      }
    } catch (_) {
      final user = FirebaseAuth.instance.currentUser;
      state = user == null
          ? const AuthStateUnauthenticated()
          : user.isAnonymous
          ? const AuthStateGuest()
          : AuthStateAuthenticated(user.uid);
      rethrow;
    }
  }
}
