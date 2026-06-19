import '../../core/api/api_client.dart';

enum CartSyncStatus { idle, syncing, failed }

class CartMessage {
  const CartMessage(this.text);
  final String text;
}

class CartLine {
  const CartLine({
    required this.product,
    required this.quantity,
    required this.priceSnapshot,
    this.variantId,
    this.pending = false,
  });

  factory CartLine.fromJson(Map<String, dynamic> json) {
    return CartLine(
      product: Product.fromJson(Map<String, dynamic>.from(json['product'] as Map)),
      variantId: json['variantId'] as String?,
      quantity: json['quantity'] as int,
      priceSnapshot: (json['priceSnapshot'] as num).toDouble(),
      pending: json['pending'] as bool? ?? false,
    );
  }

  final Product product;
  final String? variantId;
  final int quantity;
  final double priceSnapshot;
  final bool pending;

  String get id => itemKey(product.id, variantId);
  double get unitPrice => product.salePrice ?? product.price;
  double get subtotal => unitPrice * quantity;

  CartLine copyWith({
    Product? product,
    String? variantId,
    int? quantity,
    double? priceSnapshot,
    bool? pending,
  }) {
    return CartLine(
      product: product ?? this.product,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      pending: pending ?? this.pending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'variantId': variantId,
      'quantity': quantity,
      'priceSnapshot': priceSnapshot,
      'pending': pending,
    };
  }
}

class WishlistItem {
  const WishlistItem({required this.product, this.pending = false});

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      product: Product.fromJson(Map<String, dynamic>.from(json['product'] as Map)),
      pending: json['pending'] as bool? ?? false,
    );
  }

  final Product product;
  final bool pending;

  WishlistItem copyWith({Product? product, bool? pending}) {
    return WishlistItem(
      product: product ?? this.product,
      pending: pending ?? this.pending,
    );
  }

  Map<String, dynamic> toJson() {
    return {'product': product.toJson(), 'pending': pending};
  }
}

class CartState {
  const CartState({
    this.lines = const [],
    this.status = CartSyncStatus.idle,
    this.showingCache = false,
    this.message,
  });

  final List<CartLine> lines;
  final CartSyncStatus status;
  final bool showingCache;
  final CartMessage? message;

  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);
  double get total => lines.fold(0, (sum, line) => sum + line.subtotal);
  bool get isCheckoutTrusted => !showingCache && status != CartSyncStatus.failed;

  CartLine? lineFor(String productId, [String? variantId]) {
    final key = itemKey(productId, variantId);
    for (final line in lines) {
      if (line.id == key) {
        return line;
      }
    }
    return null;
  }

  CartState copyWith({
    List<CartLine>? lines,
    CartSyncStatus? status,
    bool? showingCache,
    CartMessage? message,
    bool clearMessage = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      status: status ?? this.status,
      showingCache: showingCache ?? this.showingCache,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class WishlistState {
  const WishlistState({
    this.items = const [],
    this.status = CartSyncStatus.idle,
    this.showingCache = false,
    this.message,
  });

  final List<WishlistItem> items;
  final CartSyncStatus status;
  final bool showingCache;
  final CartMessage? message;

  Set<String> get ids => items.map((item) => item.product.id).toSet();
  bool contains(String productId) => ids.contains(productId);

  WishlistState copyWith({
    List<WishlistItem>? items,
    CartSyncStatus? status,
    bool? showingCache,
    CartMessage? message,
    bool clearMessage = false,
  }) {
    return WishlistState(
      items: items ?? this.items,
      status: status ?? this.status,
      showingCache: showingCache ?? this.showingCache,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

String itemKey(String productId, [String? variantId]) {
  final variant = variantId == null || variantId.isEmpty ? 'default' : variantId;
  return '${productId}__$variant';
}
