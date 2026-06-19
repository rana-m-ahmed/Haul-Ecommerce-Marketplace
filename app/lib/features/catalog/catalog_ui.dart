import '../../core/api/api_client.dart';
import '../../shared/widgets/widgets.dart';

extension ProductCategoryLabel on ProductCategory {
  String get label {
    return switch (this) {
      ProductCategory.fashion => 'Fashion',
      ProductCategory.electronics => 'Electronics',
      ProductCategory.home => 'Home',
      ProductCategory.skincare => 'Skincare',
      ProductCategory.fitness => 'Fitness',
      ProductCategory.accessories => 'Accessories',
    };
  }
}

extension ProductSortLabel on ProductSort {
  String get label {
    return switch (this) {
      ProductSort.relevance => 'Relevance',
      ProductSort.newest => 'Newest',
      ProductSort.priceLow => 'Price: low to high',
      ProductSort.priceHigh => 'Price: high to low',
      ProductSort.rating => 'Top rated',
    };
  }
}

extension ProductCardDataMapper on Product {
  HaulProductCardData toCardData({bool isWishlisted = false}) {
    return HaulProductCardData(
      id: id,
      name: name,
      price: price,
      salePrice: salePrice,
      imageUrl: primaryImageUrl,
      rating: rating,
      reviewCount: reviewCount,
      isNew: isNew,
      isSale: isSale,
      isOutOfStock: isOutOfStock,
      isWishlisted: isWishlisted,
      category: category.label,
    );
  }
}

class ProductRouteExtra {
  const ProductRouteExtra({required this.product, required this.heroTag});

  final Product product;
  final String heroTag;
}
