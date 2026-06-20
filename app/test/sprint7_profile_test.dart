import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/core/api/api_client.dart';
import 'package:haul/core/design/design.dart';
import 'package:haul/core/session/session_resource_registry.dart';
import 'package:haul/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('profile stays usable at every required phone width', (
    tester,
  ) async {
    for (final width in [360.0, 393.0, 414.0]) {
      await tester.binding.setSurfaceSize(Size(width, 852));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(
              identityOverride: const ProfileIdentity(
                title: 'Alex Morgan',
                subtitle: 'alex@example.com',
                isGuest: false,
              ),
              wishlistProductsOverride: [_product('p001'), _product('p002')],
              logoutAction: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.text('Order history'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Log out'),
        AppSpacing.lg,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Log out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('profile portfolio screenshot', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProfileScreen(
            identityOverride: const ProfileIdentity(
              title: 'Alex Morgan',
              subtitle: 'alex@example.com',
              isGuest: false,
            ),
            wishlistProductsOverride: [
              _product('p001'),
              _product('p002'),
              _product('p003'),
            ],
            logoutAction: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ProfileScreen),
      matchesGoldenFile(
        '../../progress/screenshots/sprint7_profile/profile_393.png',
      ),
    );
  });

  test(
    'session cleanup disposes resources and removes local user caches',
    () async {
      SharedPreferences.setMockInitialValues({
        'cart_cache_u1': '[]',
        'wishlist_cache_u1': '[]',
        'unrelated_setting': true,
      });
      var disposed = false;
      Future<void> disposeResource() async => disposed = true;
      SessionResourceRegistry.instance.register(disposeResource);

      await const SessionCleaner().clear();

      final preferences = await SharedPreferences.getInstance();
      expect(disposed, isTrue);
      expect(preferences.containsKey('cart_cache_u1'), isFalse);
      expect(preferences.containsKey('wishlist_cache_u1'), isFalse);
      expect(preferences.getBool('unrelated_setting'), isTrue);
    },
  );
}

Product _product(String id) => Product(
  id: id,
  name: 'Portfolio product $id',
  description: 'A polished product.',
  price: 48,
  category: ProductCategory.home,
  colors: const ['clay'],
  materials: const ['ceramic'],
  style: const ['warm'],
  tags: const ['portfolio'],
  searchTokens: const ['portfolio'],
  imageUrls: const [],
  rating: 4.8,
  reviewCount: 18,
  inventory: 8,
  isNew: false,
  isSale: false,
  createdAt: DateTime.utc(2026, 6, 19),
);
