import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haul/features/cart/cart_screen.dart';
import 'package:haul/features/cart/models/cart_item.dart';
import 'package:haul/features/cart/providers/cart_controller.dart';

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
