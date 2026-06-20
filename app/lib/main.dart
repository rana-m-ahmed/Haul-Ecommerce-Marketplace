import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'core/design/design.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const stripePublishableKey = String.fromEnvironment(
    'HAUL_STRIPE_PUBLISHABLE_KEY',
  );
  if (stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: HaulApp()));
}

class HaulApp extends ConsumerWidget {
  const HaulApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Haul',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      routerConfig: router,
    );
  }
}
