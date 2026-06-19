import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:haul/features/entry/preferences_screen.dart';
import 'package:haul/shared/widgets/widgets.dart';

void main() {
  testWidgets('Preferences grid multi-select state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PreferencesScreen(),
        ),
      ),
    );

    // Initial state: nothing selected
    final saveButton = find.byType(HaulButton);
    expect(tester.widget<HaulButton>(saveButton).onPressed, isNull);

    // Find the 'Fashion' category tile
    final fashionTile = find.text('Fashion');
    expect(fashionTile, findsOneWidget);

    // Tap to select
    await tester.tap(fashionTile);
    await tester.pumpAndSettle();

    // Save button should now be enabled
    expect(tester.widget<HaulButton>(saveButton).onPressed, isNotNull);

    // Find the 'Electronics' tile
    final electronicsTile = find.text('Electronics');
    expect(electronicsTile, findsOneWidget);

    // Tap to select another
    await tester.tap(electronicsTile);
    await tester.pumpAndSettle();

    // Save button still enabled
    expect(tester.widget<HaulButton>(saveButton).onPressed, isNotNull);

    // Tap 'Fashion' again to deselect
    await tester.tap(fashionTile);
    await tester.pumpAndSettle();

    // Tap 'Electronics' again to deselect
    await tester.tap(electronicsTile);
    await tester.pumpAndSettle();

    // Save button should be disabled again
    expect(tester.widget<HaulButton>(saveButton).onPressed, isNull);
  });
}
