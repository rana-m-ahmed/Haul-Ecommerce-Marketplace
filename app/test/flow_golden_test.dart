import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haul/main.dart';
import 'package:haul/features/entry/onboarding_screen.dart';
import 'package:haul/features/entry/auth_screen.dart';
import 'package:haul/features/entry/preferences_screen.dart';
import 'package:haul/features/home/home_screen.dart';
import 'package:haul/shared/widgets/widgets.dart';
import 'package:haul/core/auth/auth_provider.dart';

import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

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

Future<void> pumpUntilHome(WidgetTester tester) async {
  for (var i = 0; i < 100; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(HomeScreen).evaluate().isNotEmpty) {
      return;
    }
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
        ],
        child: const HaulApp(),
      ),
    );
    await pumpUntilHome(tester);

    // Should be on Home immediately
    expect(find.byType(HomeScreen), findsOneWidget);
    await expectLater(
      find.byType(HaulApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint2_flows/flow3_1_home_returning.png',
      ),
    );
  });
}
