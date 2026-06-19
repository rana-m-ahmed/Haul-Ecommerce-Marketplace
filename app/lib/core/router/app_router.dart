import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_client.dart';
import '../auth/auth_provider.dart';
import '../../features/catalog/catalog_ui.dart';
import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/product/product_detail_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/entry/splash_screen.dart';
import '../../features/entry/onboarding_screen.dart';
import '../../features/entry/auth_screen.dart';
import '../../features/entry/preferences_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/wishlist/wishlist_screen.dart';
import '../../features/visual_search/camera_screen.dart';
import '../../core/design/design.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, style: AppTypography.h1)),
    );
  }
}

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref ref;
}

@riverpod
GoRouter appRouter(Ref ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isSplash = state.uri.path == '/splash';
      final isAuth = state.uri.path == '/auth';
      final isOnboarding = state.uri.path == '/onboarding';
      final isPreferences = state.uri.path == '/preferences';
      final isProtected =
          state.uri.path.startsWith('/orders') ||
          state.uri.path.startsWith('/profile');

      if (authState is AuthStateLoading) {
        return isSplash ? null : '/splash';
      }
      if (isSplash) {
        if (authState is AuthStateUnauthenticated) return '/onboarding';
        if (authState is AuthStateGuest) return '/home';
        if (authState is AuthStateNewUser) return '/preferences';
        if (authState is AuthStateAuthenticated) return '/home';
      }
      if (authState is AuthStateGuest && isProtected) return '/auth';
      if (isAuth || isOnboarding) {
        if (authState is AuthStateGuest) return '/home';
        if (authState is AuthStateNewUser) return '/preferences';
        if (authState is AuthStateAuthenticated) return '/home';
      }
      if (isPreferences && authState is AuthStateAuthenticated) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/preferences',
        builder: (context, state) => const PreferencesScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => SearchScreen(
                  initialCategory: _parseCategory(
                    state.uri.queryParameters['category'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const _PlaceholderScreen('Profile'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) {
          final extra = state.extra;
          return ProductDetailScreen(
            productId: state.pathParameters['id']!,
            initialProduct: extra is ProductRouteExtra
                ? extra.product
                : extra is Product
                ? extra
                : null,
            heroTag: extra is ProductRouteExtra ? extra.heroTag : null,
          );
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const _PlaceholderScreen('Checkout'),
      ),
      GoRoute(
        path: '/order-success',
        builder: (context, state) => const _PlaceholderScreen('Order Success'),
      ),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistScreen(),
      ),
    ],
  );
}

ProductCategory? _parseCategory(String? value) {
  if (value == null) return null;
  for (final category in ProductCategory.values) {
    if (category.name == value) return category;
  }
  return null;
}
