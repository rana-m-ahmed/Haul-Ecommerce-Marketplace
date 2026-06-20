import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haul/core/api/api_client.dart';
import 'package:haul/main.dart';
import 'package:haul/features/entry/onboarding_screen.dart';
import 'package:haul/features/entry/auth_screen.dart';
import 'package:haul/features/entry/preferences_screen.dart';
import 'package:haul/features/home/home_screen.dart';
import 'package:haul/features/cart/models/cart_item.dart';
import 'package:haul/features/cart/providers/cart_controller.dart';
import 'package:haul/shared/widgets/widgets.dart';
import 'package:haul/core/auth/auth_provider.dart';

import 'dart:io';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MockAuthController extends AuthController {
  final AuthState initialState;
  MockAuthController(this.initialState);

  @override
  AuthState build() => initialState;

  @override
  Future<void> loginAsGuest() async => state = const AuthStateGuest();

  @override
  Future<void> loginWithEmail(String email, String password) async {
    if (email.contains('new')) {
      state = const AuthStateNewUser('mock');
    } else {
      state = const AuthStateAuthenticated('mock');
    }
  }

  @override
  Future<void> loginWithGoogle() async => state = const AuthStateAuthenticated('mock');

  @override
  Future<void> completePreferences(List<String> categories) async => state = const AuthStateAuthenticated('mock');
}

class _MockCartController extends CartController {
  @override
  Future<List<CartItem>> build() async => const [];
}

Future<void> pumpUntilHome(WidgetTester tester) async {
  for (var i = 0; i < 100; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(HomeScreen).evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> settleHomeAnimations(WidgetTester tester) async {
  for (var index = 0; index < 24; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Create screenshot directory
    final dir = Directory('../progress/screenshots/sprint2_flows');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  });

  testWidgets('Flow 1: New user -> onboarding -> preferences -> home', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => MockAuthController(const AuthStateUnauthenticated()),
          ),
          apiClientProvider.overrideWithValue(_fakeApiClient()),
          cartControllerProvider.overrideWith(_MockCartController.new),
        ],
        child: const HaulApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Should be on Onboarding
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint2_flows/flow1_1_onboarding.png',
      ),
    );

    // Tap skip to go to Auth
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint2_flows/flow1_2_auth.png',
      ),
    );

    // Type "new" in email
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await tester.tap(find.widgetWithText(HaulButton, 'Sign In / Sign Up'));

    // Auth loading delay is 1000ms
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Should be on Preferences
    expect(find.byType(PreferencesScreen), findsOneWidget);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint2_flows/flow1_3_preferences.png',
      ),
    );

    // Select a preference
    await tester.tap(find.text('Fashion'));
    await tester.pumpAndSettle();

    // Save and continue
    await tester.tap(find.widgetWithText(HaulButton, 'Save & Continue'));
    await pumpUntilHome(tester);

    // Should be on Home
    expect(find.byType(HomeScreen), findsOneWidget);
    await settleHomeAnimations(tester);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint2_flows/flow1_4_home.png',
      ),
    );

    // Navigate back to verify no route loops
    final NavigatorState navigator = tester.state(find.byType(Navigator).last);
    expect(
      navigator.canPop(),
      false,
    ); // Shell router handles this, but generally we can't pop past home
  });

  testWidgets('Flow 2: Guest user -> home', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => MockAuthController(const AuthStateUnauthenticated()),
          ),
          apiClientProvider.overrideWithValue(_fakeApiClient()),
          cartControllerProvider.overrideWith(_MockCartController.new),
        ],
        child: const HaulApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Skip onboarding
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Tap continue as guest
    await tester.tap(find.widgetWithText(HaulButton, 'Continue as Guest'));

    // Auth loading delay is 600ms (but MockAuthController doesn't have it, it's immediate)
    await pumpUntilHome(tester);

    // Should be on Home
    expect(find.byType(HomeScreen), findsOneWidget);
    await settleHomeAnimations(tester);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint2_flows/flow2_1_home_guest.png',
      ),
    );
  });

  testWidgets('Flow 3: Returning user -> skips straight to home', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => MockAuthController(const AuthStateAuthenticated('mock')),
          ),
          apiClientProvider.overrideWithValue(_fakeApiClient()),
          cartControllerProvider.overrideWith(_MockCartController.new),
        ],
        child: const HaulApp(),
      ),
    );
    await pumpUntilHome(tester);

    // Should be on Home immediately
    expect(find.byType(HomeScreen), findsOneWidget);
    await settleHomeAnimations(tester);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint2_flows/flow3_1_home_returning.png',
      ),
    );
  });
}

ApiClient _fakeApiClient() {
  return ApiClient(
    httpClient: MockClient((request) async {
      if (request.url.path == '/search') {
        return http.Response(
          jsonEncode({
            'products': _products,
            'pageToken': null,
            'total': _products.length,
            'appliedFilters': {'sortBy': 'rating'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.startsWith('/recommendations/')) {
        return http.Response(
          jsonEncode({
            'products': _products.take(2).toList(),
            'fallbackUsed': false,
            'reason': 'preference_vector',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404, headers: {'content-type': 'application/json'});
    }),
    baseUrl: Uri.parse('http://test.local'),
    authToken: 'test-token',
  );
}

final _products = [
  {
    'id': 'p017',
    'name': 'Arc Ceramic Table Lamp',
    'description':
        'A softly curved ceramic lamp for warm desk and bedside lighting.',
    'price': 64.0,
    'salePrice': null,
    'category': 'home',
    'colors': ['clay', 'white'],
    'materials': ['ceramic', 'linen'],
    'style': ['minimal', 'warm'],
    'tags': ['lamp', 'lighting', 'decor'],
    'searchTokens': ['arc', 'ceramic', 'table', 'lamp', 'home'],
    'imageUrls': <String>[],
    'rating': 4.7,
    'reviewCount': 91,
    'inventory': 18,
    'isNew': false,
    'isSale': false,
    'createdAt': '2026-05-10T09:00:00Z',
  },
  {
    'id': 'p034',
    'name': 'Cloudlift Training Sneaker',
    'description':
        'Lightweight training sneaker with breathable mesh and responsive foam.',
    'price': 88.0,
    'salePrice': 74.0,
    'category': 'fitness',
    'colors': ['white', 'silver'],
    'materials': ['mesh', 'rubber'],
    'style': ['sporty', 'clean'],
    'tags': ['sneaker', 'training', 'sale'],
    'searchTokens': ['cloudlift', 'training', 'sneaker', 'white', 'fitness'],
    'imageUrls': <String>[],
    'rating': 4.6,
    'reviewCount': 144,
    'inventory': 22,
    'isNew': false,
    'isSale': true,
    'createdAt': '2026-04-22T09:00:00Z',
  },
];
