import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/core/api/api_client.dart';
import 'package:haul/features/checkout/checkout_screens.dart';
import 'package:haul/features/checkout/providers/orders_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('checkout displays only the backend authoritative total', (
    tester,
  ) async {
    Map<String, dynamic>? requestBody;
    final api = ApiClient(
      httpClient: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'clientSecret': 'pi_safe_secret_demo',
            'amount': 7319,
            'currency': 'usd',
          }),
          200,
        );
      }),
      baseUrl: Uri.parse('http://test.local'),
      authToken: 'test-token',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Address line 1'), '1 Main');
    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Austin');
    await tester.ensureVisible(find.text('Review order'));
    await tester.tap(find.text('Review order'));
    await tester.pumpAndSettle();

    expect(find.text('USD 73.19'), findsOneWidget);
    expect(requestBody!.keys, ['shippingAddress']);
    expect(requestBody!.containsKey('amount'), isFalse);
    expect(requestBody!.containsKey('total'), isFalse);
  });

  testWidgets('unconfigured payment remains recoverable', (tester) async {
    final api = ApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'clientSecret': 'pi_safe_secret_demo',
            'amount': 6400,
            'currency': 'usd',
          }),
          200,
        ),
      ),
      baseUrl: Uri.parse('http://test.local'),
      authToken: 'test-token',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Address line 1'), '1 Main');
    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Austin');
    await tester.ensureVisible(find.text('Review order'));
    await tester.tap(find.text('Review order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay securely'));
    await tester.pump();

    expect(
      find.text('Stripe test checkout is not configured on this build.'),
      findsOneWidget,
    );
    expect(find.text('Pay securely'), findsOneWidget);
  });

  testWidgets('success guest prompt renders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(
      const MaterialApp(
        home: OrderSuccessScreen(
          order: ConfirmOrderResponse(
            orderId: 'o_001',
            orderNumber: 'HUL-20260619-0001',
            status: 'confirmed',
          ),
          isGuestOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep your order history'), findsOneWidget);
    await expectLater(
      find.byType(OrderSuccessScreen),
      matchesGoldenFile('goldens/sprint6_order_success.png'),
    );
  });

  testWidgets('orders list renders persisted snapshots', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final order = _order();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersProvider.overrideWith((ref) => OrdersResponse(orders: [order], count: 1)),
        ],
        child: const MaterialApp(
          home: OrdersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HUL-20260619-0001'), findsOneWidget);
    expect(find.text('USD 64.00'), findsOneWidget);
    await expectLater(
      find.byType(OrdersScreen),
      matchesGoldenFile('goldens/sprint6_orders_list.png'),
    );
  });
}

OrderSnapshot _order() => OrderSnapshot(
  orderId: 'o_001',
  orderNumber: 'HUL-20260619-0001',
  items: const [
    OrderItemSnapshot(
      productId: 'p017',
      name: 'Arc Ceramic Table Lamp',
      quantity: 1,
      unitPrice: 64,
      subtotal: 64,
    ),
  ],
  total: 64,
  currency: 'usd',
  status: 'confirmed',
  shippingAddress: const ShippingAddress(
    line1: '1 Main Street',
    city: 'Austin',
    region: 'TX',
    postalCode: '78701',
    country: 'US',
  ),
  paymentIntentId: 'pi_001',
  createdAt: DateTime.utc(2026, 6, 19),
);
