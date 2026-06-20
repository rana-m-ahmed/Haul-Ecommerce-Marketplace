import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haul/core/api/api_client.dart';
import 'package:haul/features/cart/cart_screen.dart';
import 'package:haul/features/cart/models/cart_item.dart';
import 'package:haul/features/cart/providers/cart_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Cart UI with 3 items and mid-swipe delete', (WidgetTester tester) async {
    // We will set up a mock cart state
    final mockCart = [
      CartItem(productId: 'p001', quantity: 1, priceSnapshot: 49.99),
      CartItem(productId: 'p002', quantity: 2, priceSnapshot: 15.00),
      CartItem(productId: 'p003', quantity: 1, priceSnapshot: 99.00),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartControllerProvider.overrideWith(
            () => _MockCartController(mockCart),
          ),
          apiClientProvider.overrideWithValue(_fakeApiClient()),
        ],
        child: const MaterialApp(
          home: CartScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Start a swipe to delete on the second item
    await tester.drag(find.text('\$15'), const Offset(-100, 0));
    await tester.pump();

    // Take a screenshot using flutter test matching
    await expectLater(
      find.byType(CartScreen),
      matchesGoldenFile('screenshots/sprint4_cart_mid_swipe.png'),
    );
  });
}

class _MockCartController extends CartController {
  _MockCartController(this._initial);
  final List<CartItem> _initial;
  
  @override
  Future<List<CartItem>> build() async {
    return _initial;
  }
}

ApiClient _fakeApiClient() {
  return ApiClient(
    httpClient: MockClient((request) async {
      final productId = request.url.pathSegments.isNotEmpty
          ? request.url.pathSegments.last
          : '';
      final product = _products[productId];
      if (request.url.path.startsWith('/products/') && product != null) {
        return http.Response(product, 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    }),
    baseUrl: Uri.parse('http://test.local'),
    authToken: 'test-token',
  );
}

const _products = {
  'p001':
      '{"id":"p001","name":"Boxy Linen Overshirt","description":"Relaxed linen overshirt.","price":49.99,"salePrice":null,"category":"fashion","colors":["olive"],"materials":["linen"],"style":["casual"],"tags":["shirt"],"searchTokens":["boxy","linen"],"imageUrls":[],"rating":4.6,"reviewCount":88,"inventory":24,"isNew":false,"isSale":false,"createdAt":"2026-04-01T09:00:00Z"}',
  'p002':
      '{"id":"p002","name":"Ribbed Knit Midi Dress","description":"Column midi dress.","price":15.0,"salePrice":null,"category":"fashion","colors":["black"],"materials":["viscose"],"style":["modern"],"tags":["dress"],"searchTokens":["ribbed","dress"],"imageUrls":[],"rating":4.7,"reviewCount":132,"inventory":13,"isNew":false,"isSale":false,"createdAt":"2026-03-18T09:00:00Z"}',
  'p003':
      '{"id":"p003","name":"Cropped Utility Jacket","description":"Lightweight utility jacket.","price":99.0,"salePrice":null,"category":"fashion","colors":["sand"],"materials":["cotton"],"style":["utility"],"tags":["jacket"],"searchTokens":["cropped","jacket"],"imageUrls":[],"rating":4.8,"reviewCount":41,"inventory":17,"isNew":true,"isSale":false,"createdAt":"2026-06-01T09:00:00Z"}',
};
