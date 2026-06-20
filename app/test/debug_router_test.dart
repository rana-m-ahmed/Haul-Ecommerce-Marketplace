import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haul/main.dart';
import 'package:haul/core/auth/auth_provider.dart';
import 'package:haul/features/home/home_screen.dart';
import 'package:haul/features/profile/profile_screen.dart';

class MockAuthController extends AuthController {
  final AuthState initialState;
  MockAuthController(this.initialState);

  @override
  AuthState build() => initialState;
}

void main() {
  testWidgets('Print router location', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => MockAuthController(const AuthStateGuest()),
          ),
        ],
        child: const HaulApp(),
      ),
    );
    for (var index = 0; index < 50; index++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
    }
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('guest can open profile without being bounced home', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => MockAuthController(const AuthStateGuest()),
          ),
        ],
        child: const HaulApp(),
      ),
    );
    for (var index = 0; index < 50; index++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
    }

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
