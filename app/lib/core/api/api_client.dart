import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../design/app_motion.dart';

part 'api_client.g.dart';

const _configuredBaseUrl = String.fromEnvironment(
  'HAUL_API_BASE_URL',
  defaultValue: '',
);
const _configuredAuthToken = String.fromEnvironment(
  'HAUL_AUTH_TOKEN',
  defaultValue: '',
);

@riverpod
ApiClient apiClient(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);

  // Use Firebase Auth token when a user is signed in; otherwise fall back to
  // the compile-time HAUL_AUTH_TOKEN (useful for local dev with test-tokens).
  String? authToken;
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (_configuredAuthToken.isNotEmpty) {
    authToken = _configuredAuthToken;
  } else if (firebaseUser != null) {
    // Note: getIdToken() is async, so for the initial sync provider creation
    // we use the cached token. Real requests refresh the token in _headers().
    authToken = null; // Will be fetched per-request via _getAuthToken()
  }

  return ApiClient(
    httpClient: client,
    baseUrl: resolveApiBaseUrl(),
    authToken: authToken,
  );
}

Uri resolveApiBaseUrl() {
  if (_configuredBaseUrl.isNotEmpty) {
    return Uri.parse(_configuredBaseUrl);
  }
  if (!kReleaseMode) {
    return Uri.parse('https://rana-m-ahmed-haulbackend.hf.space');
  }
  return Uri.parse('https://rana-m-ahmed-haulbackend.hf.space');
}

class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required Uri baseUrl,
    String? authToken,
  }) : this._(httpClient: httpClient, baseUrl: baseUrl, authToken: authToken);

  ApiClient._({
    required this._httpClient,
    required this._baseUrl,
    this._authToken,
  });

  final http.Client _httpClient;
  final Uri _baseUrl;
  final String? _authToken;

  Future<HealthResponse> health() async {
    final json = await _get('/health', authenticated: false);
    return HealthResponse.fromJson(json);
  }

  Future<SearchResponse> searchProducts(SearchRequest request) async {
    final json = await _post('/search', request.toJson());
    return SearchResponse.fromJson(json);
  }

  Future<Product> getProduct(String id) async {
    final json = await _get('/products/${Uri.encodeComponent(id)}');
    return Product.fromJson(json);
  }

  Future<RecommendationsResponse> getRecommendations(String uid) async {
    final json = await _get('/recommendations/${Uri.encodeComponent(uid)}');
    return RecommendationsResponse.fromJson(json);
  }

  Future<VisualSearchResponse> visualSearch({
    required String imagePath,
    List<int>? imageBytes,
    List<String> mlKitLabels = const [],
  }) async {
    final request = http.MultipartRequest('POST', _uri('/visual-search'));
    request.headers.addAll(await _headers(includeContentType: false));
    request.fields['mlKitLabels'] = mlKitLabels.join(',');
    final extension = imagePath.split('.').last.toLowerCase();
    final subtype = extension == 'png'
        ? 'png'
        : extension == 'heic' || extension == 'heif'
        ? extension
        : 'jpeg';
    request.files.add(
      imageBytes == null
          ? await http.MultipartFile.fromPath(
              'image',
              imagePath,
              contentType: MediaType('image', subtype),
            )
          : http.MultipartFile.fromBytes(
              'image',
              imageBytes,
              filename: imagePath.split(RegExp(r'[/\\]')).last,
              contentType: MediaType('image', subtype),
            ),
    );
    final streamed = await _httpClient
        .send(request)
        .timeout(AppMotion.durationNetworkTimeout);
    final response = await http.Response.fromStream(streamed);
    return VisualSearchResponse.fromJson(_decode(response));
  }

  Future<ExplainProductResponse> explainProduct({
    required String uid,
    required String productId,
  }) async {
    final json = await _post('/explain-product', {
      'uid': uid,
      'productId': productId,
    });
    return ExplainProductResponse.fromJson(json);
  }

  Future<PaymentIntentResponse> createPaymentIntent(
    ShippingAddress address,
  ) async {
    final json = await _post('/create-payment-intent', {
      'shippingAddress': address.toJson(),
    });
    return PaymentIntentResponse.fromJson(json);
  }

  Future<ConfirmOrderResponse> confirmOrder(String paymentIntentId) async {
    final json = await _post('/orders/confirm', {
      'paymentIntentId': paymentIntentId,
    });
    return ConfirmOrderResponse.fromJson(json);
  }

  Future<OrdersResponse> getOrders(String uid) async {
    final json = await _get('/orders/${Uri.encodeComponent(uid)}');
    return OrdersResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _httpClient
        .get(_uri(path), headers: await _headers(authenticated: authenticated))
        .timeout(AppMotion.durationNetworkTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient
        .post(_uri(path), headers: await _headers(), body: jsonEncode(body))
        .timeout(AppMotion.durationNetworkTimeout);
    return _decode(response);
  }

  Uri _uri(String path) {
    final normalizedBase = _baseUrl.path.endsWith('/')
        ? _baseUrl.path.substring(0, _baseUrl.path.length - 1)
        : _baseUrl.path;
    return _baseUrl.replace(path: '$normalizedBase$path');
  }

  /// Returns a fresh auth token — either the compile-time override or a live
  /// Firebase ID token from the currently signed-in user.
  Future<String?> _getAuthToken() async {
    if (_authToken != null && _authToken.isNotEmpty) {
      return _authToken;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  Future<Map<String, String>> _headers({
    bool authenticated = true,
    bool includeContentType = true,
  }) async {
    final token = authenticated ? await _getAuthToken() : null;
    return {
      'Accept': 'application/json',
      if (includeContentType) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }
    final error = decoded is Map<String, dynamic>
        ? ApiError.fromJson(decoded)
        : ApiError(error: 'http_error', message: response.body);
    throw ApiException(response.statusCode, error);
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.error);

  final int statusCode;
  final ApiError error;

  @override
  String toString() => 'ApiException($statusCode): ${error.message}';
}

class ApiError {
  const ApiError({
    required this.error,
    required this.message,
    this.fallbackMode,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      error: json['error'] as String? ?? 'api_error',
      message: json['message'] as String? ?? 'Request failed',
      fallbackMode: json['fallbackMode'] as bool?,
    );
  }

  final String error;
  final String message;
  final bool? fallbackMode;
}

enum ProductCategory {
  fashion,
  electronics,
  home,
  skincare,
  fitness,
  accessories,
}

enum ProductSort {
  relevance('relevance'),
  newest('newest'),
  priceLow('price_low'),
  priceHigh('price_high'),
  rating('rating');

  const ProductSort(this.apiValue);
  final String apiValue;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.colors,
    required this.materials,
    required this.style,
    required this.tags,
    required this.searchTokens,
    required this.imageUrls,
    required this.rating,
    required this.reviewCount,
    required this.inventory,
    required this.isNew,
    required this.isSale,
    required this.createdAt,
    this.salePrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      salePrice: (json['salePrice'] as num?)?.toDouble(),
      category: ProductCategory.values.byName(json['category'] as String),
      colors: _stringList(json['colors']),
      materials: _stringList(json['materials']),
      style: _stringList(json['style']),
      tags: _stringList(json['tags']),
      searchTokens: _stringList(json['searchTokens']),
      imageUrls: _stringList(json['imageUrls']),
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['reviewCount'] as int,
      inventory: json['inventory'] as int,
      isNew: json['isNew'] as bool,
      isSale: json['isSale'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String name;
  final String description;
  final double price;
  final double? salePrice;
  final ProductCategory category;
  final List<String> colors;
  final List<String> materials;
  final List<String> style;
  final List<String> tags;
  final List<String> searchTokens;
  final List<String> imageUrls;
  final double rating;
  final int reviewCount;
  final int inventory;
  final bool isNew;
  final bool isSale;
  final DateTime createdAt;

  bool get isOutOfStock => inventory <= 0;
  String? get primaryImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'salePrice': salePrice,
      'category': category.name,
      'colors': colors,
      'materials': materials,
      'style': style,
      'tags': tags,
      'searchTokens': searchTokens,
      'imageUrls': imageUrls,
      'rating': rating,
      'reviewCount': reviewCount,
      'inventory': inventory,
      'isNew': isNew,
      'isSale': isSale,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}

class SearchRequest {
  const SearchRequest({
    this.query,
    this.category,
    this.colors = const [],
    this.materials = const [],
    this.tags = const [],
    this.minPrice,
    this.maxPrice,
    this.sortBy = ProductSort.relevance,
    this.pageSize = 12,
    this.pageToken,
  });

  final String? query;
  final ProductCategory? category;
  final List<String> colors;
  final List<String> materials;
  final List<String> tags;
  final double? minPrice;
  final double? maxPrice;
  final ProductSort sortBy;
  final int pageSize;
  final String? pageToken;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'category': category?.name,
      'colors': colors,
      'materials': materials,
      'tags': tags,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'sortBy': sortBy.apiValue,
      'pageSize': pageSize,
      'pageToken': pageToken,
    };
  }
}

class SearchResponse {
  const SearchResponse({
    required this.products,
    required this.total,
    required this.appliedFilters,
    this.pageToken,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      products: _products(json['products']),
      pageToken: json['pageToken'] as String?,
      total: json['total'] as int,
      appliedFilters: Map<String, dynamic>.from(
        json['appliedFilters'] as Map? ?? const {},
      ),
    );
  }

  final List<Product> products;
  final String? pageToken;
  final int total;
  final Map<String, dynamic> appliedFilters;
}

class RecommendationsResponse {
  const RecommendationsResponse({
    required this.products,
    required this.fallbackUsed,
    required this.reason,
  });

  factory RecommendationsResponse.fromJson(Map<String, dynamic> json) {
    return RecommendationsResponse(
      products: _products(json['products']),
      fallbackUsed: json['fallbackUsed'] as bool,
      reason: json['reason'] as String,
    );
  }

  final List<Product> products;
  final bool fallbackUsed;
  final String reason;
}

class DetectedAttributes {
  const DetectedAttributes({
    required this.primaryCategory,
    required this.colors,
    required this.materials,
    this.objectType,
    this.style,
  });

  factory DetectedAttributes.fromJson(Map<String, dynamic> json) {
    return DetectedAttributes(
      primaryCategory: ProductCategory.values.byName(
        json['primaryCategory'] as String,
      ),
      objectType: json['objectType'] as String?,
      colors: _stringList(json['colors']),
      materials: _stringList(json['materials']),
      style: json['style'] as String?,
    );
  }

  final ProductCategory primaryCategory;
  final String? objectType;
  final List<String> colors;
  final List<String> materials;
  final String? style;
}

class VisualSearchResponse {
  const VisualSearchResponse({
    required this.products,
    required this.detectedAttributes,
    required this.matchScores,
    required this.fallbackMode,
    required this.queryTokens,
  });

  factory VisualSearchResponse.fromJson(Map<String, dynamic> json) {
    return VisualSearchResponse(
      products: _products(json['products']),
      detectedAttributes: DetectedAttributes.fromJson(
        Map<String, dynamic>.from(json['detectedAttributes'] as Map),
      ),
      matchScores: (json['matchScores'] as List? ?? const [])
          .map((value) => (value as num).toDouble())
          .toList(growable: false),
      fallbackMode: json['fallbackMode'] as bool,
      queryTokens: _stringList(json['queryTokens']),
    );
  }

  final List<Product> products;
  final DetectedAttributes detectedAttributes;
  final List<double> matchScores;
  final bool fallbackMode;
  final List<String> queryTokens;
}

class ExplainProductResponse {
  const ExplainProductResponse({
    required this.explanationText,
    required this.provider,
    required this.cached,
  });

  factory ExplainProductResponse.fromJson(Map<String, dynamic> json) {
    return ExplainProductResponse(
      explanationText: json['explanationText'] as String,
      provider: json['provider'] as String,
      cached: json['cached'] as bool,
    );
  }

  final String explanationText;
  final String provider;
  final bool cached;
}

class HealthResponse {
  const HealthResponse({
    required this.status,
    required this.version,
    required this.timestamp,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String,
      version: json['version'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  final String status;
  final String version;
  final DateTime timestamp;
}

class ShippingAddress {
  const ShippingAddress({
    required this.line1,
    required this.city,
    required this.country,
    this.line2,
    this.region,
    this.postalCode,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) =>
      ShippingAddress(
        line1: json['line1'] as String,
        line2: json['line2'] as String?,
        city: json['city'] as String,
        region: json['region'] as String?,
        postalCode: json['postalCode'] as String?,
        country: json['country'] as String,
      );

  final String line1;
  final String? line2;
  final String city;
  final String? region;
  final String? postalCode;
  final String country;

  Map<String, dynamic> toJson() => {
    'line1': line1,
    'line2': line2,
    'city': city,
    'region': region,
    'postalCode': postalCode,
    'country': country,
  };
}

class PaymentIntentResponse {
  const PaymentIntentResponse({
    required this.clientSecret,
    required this.amount,
    required this.currency,
  });

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) =>
      PaymentIntentResponse(
        clientSecret: json['clientSecret'] as String,
        amount: json['amount'] as int,
        currency: json['currency'] as String,
      );

  final String clientSecret;
  final int amount;
  final String currency;

  String get paymentIntentId => clientSecret.split('_secret_').first;
}

class ConfirmOrderResponse {
  const ConfirmOrderResponse({
    required this.orderId,
    required this.orderNumber,
    required this.status,
  });

  factory ConfirmOrderResponse.fromJson(Map<String, dynamic> json) =>
      ConfirmOrderResponse(
        orderId: json['orderId'] as String,
        orderNumber: json['orderNumber'] as String,
        status: json['status'] as String,
      );

  final String orderId;
  final String orderNumber;
  final String status;
}

class OrderItemSnapshot {
  const OrderItemSnapshot({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.variantId,
  });

  factory OrderItemSnapshot.fromJson(Map<String, dynamic> json) =>
      OrderItemSnapshot(
        productId: json['productId'] as String,
        variantId: json['variantId'] as String?,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
      );

  final String productId;
  final String? variantId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
}

class OrderSnapshot {
  const OrderSnapshot({
    required this.orderId,
    required this.orderNumber,
    required this.items,
    required this.total,
    required this.currency,
    required this.status,
    required this.shippingAddress,
    required this.paymentIntentId,
    required this.createdAt,
  });

  factory OrderSnapshot.fromJson(Map<String, dynamic> json) => OrderSnapshot(
    orderId: json['orderId'] as String,
    orderNumber: json['orderNumber'] as String,
    items: (json['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(OrderItemSnapshot.fromJson)
        .toList(growable: false),
    total: (json['total'] as num).toDouble(),
    currency: json['currency'] as String,
    status: json['status'] as String,
    shippingAddress: ShippingAddress.fromJson(
      Map<String, dynamic>.from(json['shippingAddress'] as Map),
    ),
    paymentIntentId: json['paymentIntentId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String orderId;
  final String orderNumber;
  final List<OrderItemSnapshot> items;
  final double total;
  final String currency;
  final String status;
  final ShippingAddress shippingAddress;
  final String paymentIntentId;
  final DateTime createdAt;
}

class OrdersResponse {
  const OrdersResponse({required this.orders, required this.count});

  factory OrdersResponse.fromJson(Map<String, dynamic> json) => OrdersResponse(
    orders: (json['orders'] as List)
        .cast<Map<String, dynamic>>()
        .map(OrderSnapshot.fromJson)
        .toList(growable: false),
    count: json['count'] as int,
  );

  final List<OrderSnapshot> orders;
  final int count;
}

List<Product> _products(Object? value) {
  return (value as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(Product.fromJson)
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  return (value as List? ?? const []).cast<String>().toList(growable: false);
}
