import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haul/core/api/api_client.dart';
import 'package:haul/core/auth/auth_provider.dart';
import 'package:haul/core/design/design.dart';
import 'package:haul/features/home/home_provider.dart';
import 'package:haul/features/product/product_detail_screen.dart';
import 'package:haul/features/visual_search/camera_gateway.dart';
import 'package:haul/features/visual_search/camera_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MockAuthController extends AuthController {
  _MockAuthController(this.initialState);

  final AuthState initialState;

  @override
  AuthState build() => initialState;
}

class _FakeCameraGateway implements CameraGateway {
  _FakeCameraGateway({this.failure, required this.imagePath});

  final CameraFailure? failure;
  final String imagePath;
  bool _flash = false;
  int captureCount = 0;

  @override
  bool get canUseFlash => true;

  @override
  bool get flashEnabled => _flash;

  @override
  Future<void> initialize() async {
    if (failure != null) throw failure!;
  }

  @override
  Widget buildPreview() {
    return const ColoredBox(
      color: AppColors.textSecondary,
      child: Center(
        child: Icon(
          Icons.chair_outlined,
          color: AppColors.surface,
          size: AppSpacing.xxxl,
        ),
      ),
    );
  }

  @override
  Future<String> capture() async {
    captureCount++;
    return imagePath;
  }

  @override
  Future<List<int>> bytesFor(String imagePath) => File(imagePath).readAsBytes();

  @override
  Future<void> dispose() async {}

  @override
  Future<List<String>> labelsFor(String imagePath) async {
    return const ['chair', 'home', 'minimal'];
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<String?> pickFromGallery() async => imagePath;

  @override
  Future<void> toggleFlash() async => _flash = !_flash;
}

void main() {
  late Directory screenshotDirectory;
  late File imageFile;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    screenshotDirectory = Directory(
      '../progress/screenshots/sprint5_visual_search',
    );
    screenshotDirectory.createSync(recursive: true);
    imageFile = File('${Directory.systemTemp.path}/haul_visual_test.png');
    await imageFile.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  });

  testWidgets('camera permission denial is recoverable', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CameraScreen(
            gateway: _FakeCameraGateway(
              imagePath: imageFile.path,
              failure: const CameraFailure(
                CameraFailureKind.permissionDenied,
                'Camera permission is required.',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('visual search shows processing, waking, and fallback results', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final visualResponse = Completer<http.Response>();
    final api = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path == '/visual-search') {
          return visualResponse.future;
        }
        return http.Response('{}', 404);
      }),
      baseUrl: Uri.parse('http://test.local'),
      authToken: 'test-token',
    );
    final gateway = _FakeCameraGateway(imagePath: imageFile.path);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
          ),
          home: CameraScreen(gateway: gateway),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint5_visual_search/01_camera_ready.png',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('capture-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(gateway.captureCount, 1);
    expect(find.text('Reading the visual signals'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint5_visual_search/02_processing.png',
      ),
    );

    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.text('Waking up your search'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint5_visual_search/03_waking_up.png',
      ),
    );

    visualResponse.complete(
      http.Response(
        jsonEncode(_visualSearchPayload),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(find.text('On-device match'), findsWidgets);
    expect(find.text('Closest matches'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../progress/screenshots/sprint5_visual_search/04_results.png',
      ),
    );
  });

  test('For You personalizes accounts and trends for guests', () async {
    final paths = <String>[];
    final api = ApiClient(
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.startsWith('/recommendations/')) {
          return http.Response(
            jsonEncode({
              'products': [_product],
              'fallbackUsed': false,
              'reason': 'preference_vector',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'products': [_product],
            'pageToken': null,
            'total': 1,
            'appliedFilters': {'sortBy': 'rating'},
          }),
          200,
        );
      }),
      baseUrl: Uri.parse('http://test.local'),
      authToken: 'test-token',
    );
    final account = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(
          () => _MockAuthController(const AuthStateAuthenticated('u_001')),
        ),
      ],
    );
    addTearDown(account.dispose);
    final personalized = await account.read(forYouProductsProvider.future);
    expect(personalized.fallbackUsed, isFalse);
    expect(paths.single, '/recommendations/u_001');

    paths.clear();
    final guest = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(
          () => _MockAuthController(const AuthStateGuest()),
        ),
      ],
    );
    addTearDown(guest.dispose);
    final trending = await guest.read(forYouProductsProvider.future);
    expect(trending.fallbackUsed, isTrue);
    expect(paths.single, '/search');
  });

  testWidgets('explanation fades in for accounts and stays absent for guests', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    var explanationCalls = 0;
    final api = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path == '/products/p017') {
          return http.Response(jsonEncode(_product), 200);
        }
        if (request.url.path == '/explain-product') {
          explanationCalls++;
          return http.Response(
            jsonEncode({
              'explanationText':
                  "Because you showed interest in home, this product's ceramic may match your style.",
              'provider': 'template',
              'cached': false,
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
      baseUrl: Uri.parse('http://test.local'),
      authToken: 'test-token',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(
            () => _MockAuthController(const AuthStateAuthenticated('u_001')),
          ),
        ],
        child: MaterialApp(
          home: ProductDetailScreen(
            productId: 'p017',
            initialProduct: Product.fromJson(_product),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-explanation')), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const ValueKey('ai-explanation')), findsOneWidget);
    expect(explanationCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(
            () => _MockAuthController(const AuthStateGuest()),
          ),
        ],
        child: MaterialApp(
          home: ProductDetailScreen(
            productId: 'p017',
            initialProduct: Product.fromJson(_product),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const ValueKey('ai-explanation')), findsNothing);
    expect(explanationCalls, 1);
  });
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final _visualSearchPayload = {
  'products': [_product, _fitnessProduct],
  'detectedAttributes': {
    'primaryCategory': 'home',
    'objectType': 'chair',
    'colors': ['clay'],
    'materials': ['wood'],
    'style': 'minimal',
  },
  'matchScores': [0.94, 0.76],
  'fallbackMode': true,
  'queryTokens': ['chair', 'home', 'minimal'],
};

final _product = {
  'id': 'p017',
  'name': 'Arc Ceramic Table Lamp',
  'description': 'A softly curved ceramic lamp for warm bedside lighting.',
  'price': 64.0,
  'salePrice': null,
  'category': 'home',
  'colors': ['clay', 'white'],
  'materials': ['ceramic', 'linen'],
  'style': ['minimal', 'warm'],
  'tags': ['lamp', 'lighting', 'decor'],
  'searchTokens': ['arc', 'ceramic', 'lamp'],
  'imageUrls': <String>[],
  'rating': 4.7,
  'reviewCount': 91,
  'inventory': 18,
  'isNew': false,
  'isSale': false,
  'createdAt': '2026-05-10T09:00:00Z',
};

final _fitnessProduct = {
  ..._product,
  'id': 'p034',
  'name': 'Cloudlift Training Sneaker',
  'category': 'fitness',
  'price': 88.0,
  'salePrice': 74.0,
  'isSale': true,
};
