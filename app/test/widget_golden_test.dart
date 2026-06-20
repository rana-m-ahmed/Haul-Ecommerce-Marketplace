import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:haul/core/design/design.dart';
import 'package:haul/shared/widgets/widgets.dart';

/// Golden tests for all shared widgets at three breakpoints.
///
/// Breakpoints: 360px, 393px, 414px.
/// Run: `flutter test --update-goldens` to generate reference images.
/// Run: `flutter test` to verify against references.
///
/// NOTE: We use `tester.pump(Duration)` instead of `pumpAndSettle` because
/// several widgets have infinite animations (loading spinner, shimmer, AI badge
/// shimmer). `pumpAndSettle` would time out.

const _breakpoints = <(String name, double width)>[
  ('360', 360),
  ('393', 393),
  ('414', 414),
];

const _screenHeight = 900.0;

/// Pump enough frames for layout to complete without waiting for
/// infinite animations to stop.
const _pumpDuration = Duration(milliseconds: 500);

Widget _wrapInApp(Widget child, {double width = 360}) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  // ── HaulButton golden tests ────────────────────────────────────────────

  group('HaulButton', () {
    for (final (name, width) in _breakpoints) {
      testWidgets('primary at ${name}px', (tester) async {
        tester.view.physicalSize = Size(width, _screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HaulButton(label: 'Add to Cart', onPressed: () {}),
                AppSpacing.gapMd,
                HaulButton(
                  label: 'Add to Cart',
                  onPressed: () {},
                  icon: const Icon(Icons.shopping_bag_outlined),
                ),
                AppSpacing.gapMd,
                const HaulButton(label: 'Disabled', onPressed: null),
                AppSpacing.gapMd,
                HaulButton(label: 'Loading', onPressed: () {}, isLoading: true),
                AppSpacing.gapMd,
                HaulButton(
                  label: 'Secondary',
                  onPressed: () {},
                  variant: HaulButtonVariant.secondary,
                ),
                AppSpacing.gapMd,
                HaulButton(
                  label: 'Text',
                  onPressed: () {},
                  variant: HaulButtonVariant.text,
                ),
                AppSpacing.gapMd,
                HaulButton(
                  label: 'Full Width',
                  onPressed: () {},
                  fullWidth: true,
                ),
              ],
            ),
            width: width,
          ),
        );

        await tester.pump(_pumpDuration);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/haul_button_primary_$name.png'),
        );
      });
    }
  });

  // ── HaulProductCard golden tests ───────────────────────────────────────

  group('HaulProductCard grid', () {
    final states = <(String, HaulProductCardData)>[
      (
        'normal',
        const HaulProductCardData(
          id: 'test1',
          name: 'Minimalist Leather Tote',
          price: 89,
          rating: 4.5,
          reviewCount: 128,
          category: 'fashion',
        ),
      ),
      (
        'sale',
        const HaulProductCardData(
          id: 'test2',
          name: 'Cloudlift Training Sneaker',
          price: 88,
          salePrice: 74,
          isSale: true,
          rating: 4.6,
          reviewCount: 144,
          category: 'fitness',
        ),
      ),
      (
        'new',
        const HaulProductCardData(
          id: 'test3',
          name: 'Arc Ceramic Table Lamp',
          price: 64,
          isNew: true,
          rating: 4.7,
          reviewCount: 91,
          category: 'home',
        ),
      ),
      (
        'out_of_stock',
        const HaulProductCardData(
          id: 'test4',
          name: 'Glow Serum Set',
          price: 42,
          isOutOfStock: true,
          rating: 4.8,
          reviewCount: 203,
          category: 'skincare',
        ),
      ),
      (
        'wishlisted',
        const HaulProductCardData(
          id: 'test5',
          name: 'Ember Wireless Speaker',
          price: 56,
          isWishlisted: true,
          rating: 4.3,
          reviewCount: 87,
          category: 'electronics',
        ),
      ),
      (
        'visual_search_match',
        const HaulProductCardData(
          id: 'test6',
          name: 'Linen Wrapped Candle',
          price: 24,
          matchScore: 0.91,
          rating: 4.9,
          reviewCount: 312,
          category: 'home',
        ),
      ),
    ];

    for (final (stateName, data) in states) {
      for (final (bpName, width) in _breakpoints) {
        testWidgets('$stateName at ${bpName}px', (tester) async {
          tester.view.physicalSize = Size(width, _screenHeight);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            _wrapInApp(
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: (width - AppSpacing.md * 3) / 2,
                  child: HaulProductCard(
                    data: data,
                    variant: HaulCardVariant.grid,
                    onTap: () {},
                    onWishlistToggle: () {},
                  ),
                ),
              ),
              width: width,
            ),
          );

          await tester.pump(_pumpDuration);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/haul_product_card_grid_${stateName}_$bpName.png',
            ),
          );
        });
      }
    }
  });

  group('HaulProductCard horizontal', () {
    for (final (bpName, width) in _breakpoints) {
      testWidgets('horizontal at ${bpName}px', (tester) async {
        tester.view.physicalSize = Size(width, _screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: HaulProductCard(
                data: const HaulProductCardData(
                  id: 'test_h1',
                  name: 'Cloudlift Training Sneaker',
                  price: 88,
                  salePrice: 74,
                  isSale: true,
                  rating: 4.6,
                  reviewCount: 144,
                  category: 'fitness',
                ),
                variant: HaulCardVariant.horizontal,
                onTap: () {},
                onWishlistToggle: () {},
              ),
            ),
            width: width,
          ),
        );

        await tester.pump(_pumpDuration);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/haul_product_card_horizontal_$bpName.png',
          ),
        );
      });
    }
  });

  // ── HaulSkeleton golden tests ──────────────────────────────────────────

  group('HaulSkeleton', () {
    for (final (bpName, width) in _breakpoints) {
      testWidgets('product card skeleton at ${bpName}px', (tester) async {
        tester.view.physicalSize = Size(width, _screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: (width - AppSpacing.md * 3) / 2,
                child: HaulSkeleton.productCard(),
              ),
            ),
            width: width,
          ),
        );

        await tester.pump(_pumpDuration);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/haul_skeleton_grid_$bpName.png'),
        );
      });

      testWidgets('horizontal skeleton at ${bpName}px', (tester) async {
        tester.view.physicalSize = Size(width, _screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: HaulSkeleton.productCardHorizontal(),
            ),
            width: width,
          ),
        );

        await tester.pump(_pumpDuration);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/haul_skeleton_horizontal_$bpName.png'),
        );
      });
    }
  });

  // ── HaulAiBadge golden tests ───────────────────────────────────────────

  group('HaulAiBadge', () {
    for (final (bpName, width) in _breakpoints) {
      testWidgets('ai badge at ${bpName}px', (tester) async {
        tester.view.physicalSize = Size(width, _screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HaulAiBadge(),
                SizedBox(width: AppSpacing.md),
                HaulAiBadge(compact: true),
              ],
            ),
            width: width,
          ),
        );

        await tester.pump(_pumpDuration);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/haul_ai_badge_$bpName.png'),
        );
      });
    }
  });

  // ── HaulEmptyState golden tests ────────────────────────────────────────

  group('HaulEmptyState', () {
    for (final (bpName, width) in _breakpoints) {
      testWidgets('empty state at ${bpName}px', (tester) async {
        tester.view.physicalSize = Size(width, _screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
            HaulEmptyState(
              title: 'Your cart is empty',
              subtitle: 'Browse our collection and find something you love.',
              actionLabel: 'Start Shopping',
              onAction: () {},
            ),
            width: width,
          ),
        );

        await tester.pump(_pumpDuration);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/haul_empty_state_$bpName.png'),
        );
      });
    }
  });

  // ── HaulErrorState golden tests ────────────────────────────────────────

  group('HaulErrorState', () {
    for (final (bpName, width) in _breakpoints) {
      testWidgets('error state at ${bpName}px', (tester) async {
        tester.view.physicalSize = Size(width, _screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapInApp(
            HaulErrorState(
              title: 'Something went wrong',
              subtitle: 'Check your connection and try again.',
              onRetry: () {},
            ),
            width: width,
          ),
        );

        await tester.pump(_pumpDuration);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/haul_error_state_$bpName.png'),
        );
      });
    }
  });
}
