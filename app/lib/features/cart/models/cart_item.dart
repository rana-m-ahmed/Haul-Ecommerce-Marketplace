class CartItem {
  const CartItem({
    required this.productId,
    required this.quantity,
    required this.priceSnapshot,
    this.variantId,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'] as String,
      variantId: json['variantId'] as String?,
      quantity: json['quantity'] as int,
      priceSnapshot: (json['priceSnapshot'] as num).toDouble(),
    );
  }

  final String productId;
  final String? variantId;
  final int quantity;
  final double priceSnapshot;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      if (variantId != null) 'variantId': variantId,
      'quantity': quantity,
      'priceSnapshot': priceSnapshot,
    };
  }

  CartItem copyWith({
    String? productId,
    String? variantId,
    int? quantity,
    double? priceSnapshot,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
    );
  }
}

class CartChange {
  const CartChange({
    required this.productId,
    required this.reason,
    this.variantId,
    this.oldPrice,
    this.newPrice,
    this.oldQuantity,
    this.newQuantity,
  });

  factory CartChange.fromJson(Map<String, dynamic> json) {
    return CartChange(
      productId: json['productId'] as String,
      variantId: json['variantId'] as String?,
      reason: json['reason'] as String,
      oldPrice: (json['oldPrice'] as num?)?.toDouble(),
      newPrice: (json['newPrice'] as num?)?.toDouble(),
      oldQuantity: json['oldQuantity'] as int?,
      newQuantity: json['newQuantity'] as int?,
    );
  }

  final String productId;
  final String? variantId;
  final String reason;
  final double? oldPrice;
  final double? newPrice;
  final int? oldQuantity;
  final int? newQuantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      if (variantId != null) 'variantId': variantId,
      'reason': reason,
      if (oldPrice != null) 'oldPrice': oldPrice,
      if (newPrice != null) 'newPrice': newPrice,
      if (oldQuantity != null) 'oldQuantity': oldQuantity,
      if (newQuantity != null) 'newQuantity': newQuantity,
    };
  }
}
