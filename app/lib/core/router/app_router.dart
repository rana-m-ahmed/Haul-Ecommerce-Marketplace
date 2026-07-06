import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/checkout/payment_flow/payment_method_screen.dart';
import '../../features/checkout/payment_flow/add_card_screen.dart';

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
import '../../features/checkout/checkout_screens.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/recommendation_settings_screen.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

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
      final isLinking = isAuth && state.uri.queryParameters['link'] == 'true';
      final isOnboarding = state.uri.path == '/onboarding';
      final isPreferences = state.uri.path == '/preferences';

      if (authState is AuthStateLoading) {
        return isSplash ? null : '/splash';
      }
      // Splash screen handles its own navigation when auth is ready and timer finishes.
      if ((isAuth && !isLinking) || isOnboarding) {
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
      GoRoute(
        path: '/auth',
        builder: (context, state) =>
            AuthScreen(linkMode: state.uri.queryParameters['link'] == 'true'),
      ),
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
                builder: (context, state) => const ProfileScreen(),
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
        path: '/recommendation-settings',
        builder: (context, state) => const RecommendationSettingsScreen(),
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
        builder: (context, state) => const CheckoutScreen(),
        routes: [
          GoRoute(
            path: 'payment-method',
            builder: (context, state) => PaymentMethodScreen(
              intent: state.extra! as PaymentIntentResponse,
            ),
          ),
          GoRoute(
            path: 'add-card',
            builder: (context, state) => AddCardScreen(
              intent: state.extra! as PaymentIntentResponse,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/order-success',
        builder: (context, state) =>
            OrderSuccessScreen(order: state.extra! as ConfirmOrderResponse),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                OrderDetailScreen(order: state.extra! as OrderSnapshot),
          ),
        ],
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
