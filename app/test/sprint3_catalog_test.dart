import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haul/core/api/api_client.dart';
import 'package:haul/core/auth/auth_provider.dart';
import 'package:haul/features/product/product_detail_screen.dart';
import 'package:haul/main.dart';
import 'package:haul/shared/widgets/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MockAuthController extends AuthController {
  MockAuthController(this.initialState);

  final AuthState initialState;

  @override
  AuthState build() => initialState;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = Directory('../progress/screenshots');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  });

  testWidgets('Home and Search render with catalog data', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => MockAuthController(const AuthStateAuthenticated('u_001')),
          ),
          apiClientProvider.overrideWithValue(_fakeApiClient()),
        ],
        child: const HaulApp(),
      ),
    );
    await tester.pump();
    for (var index = 0; index < 100; index++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Find your next signal.').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Find your next signal.'), findsOneWidget);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile('../../progress/screenshots/sprint3_home.png'),
    );

    await tester.tap(find.text('Search').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), 'lamp');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('results'), findsOneWidget);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile('../../progress/screenshots/sprint3_search.png'),
    );

    expect(find.byType(HaulProductCard, skipOffstage: true), findsWidgets);
  });

  testWidgets('Product detail renders with catalog data', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_fakeApiClient())],
        child: MaterialApp(
          home: ProductDetailScreen(
            productId: 'p017',
            initialProduct: Product.fromJson(_products.first),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint3_product_detail.png',
      ),
    );
  });

  testWidgets('404 product navigates away with snackbar', (tester) async {
    final router = GoRouter(
      initialLocation: '/products/missing',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('Home fallback')),
        ),
        GoRoute(
          path: '/products/:id',
          builder: (context, state) =>
              ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_fakeApiClient())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home fallback'), findsOneWidget);
    expect(find.text('Product not found.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
            'appliedFilters': {'sortBy': 'relevance'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/products/p017') {
        return http.Response(
          jsonEncode(_products.first),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode({
          'error': 'not_found',
          'message': 'No product with that id',
        }),
        404,
        headers: {'content-type': 'application/json'},
      );
    }),
    baseUrl: Uri.parse('http://test.local'),
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
  {
    'id': 'p003',
    'name': 'Cropped Utility Jacket',
    'description':
        'Lightweight utility jacket with roomy pockets and a cropped shape.',
    'price': 118.0,
    'salePrice': null,
    'category': 'fashion',
    'colors': ['sand', 'navy'],
    'materials': ['cotton', 'recycled polyester'],
    'style': ['utility', 'street'],
    'tags': ['jacket', 'new', 'outerwear'],
    'searchTokens': ['cropped', 'utility', 'jacket', 'fashion'],
    'imageUrls': <String>[],
    'rating': 4.8,
    'reviewCount': 41,
    'inventory': 17,
    'isNew': true,
    'isSale': false,
    'createdAt': '2026-06-01T09:00:00Z',
  },
];
