class RetailerProductUiModel {
  RetailerProductUiModel({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.type,
    required this.description,
    required this.priceText,
    required this.stockQty,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final String type;
  final String description;
  final String priceText;
  final int stockQty;
  final String imageUrl;

  bool get isOutOfStock => stockQty <= 0;

  String get formattedPrice {
    final parsedPrice = double.tryParse(priceText);
    if (parsedPrice == null) {
      return priceText;
    }

    return parsedPrice.toStringAsFixed(
      parsedPrice.truncateToDouble() == parsedPrice ? 0 : 2,
    );
  }

  String get stockLabel {
    if (isOutOfStock) {
      return 'Sold out';
    }
    return '$stockQty units available';
  }

  factory RetailerProductUiModel.fromMap(Map<String, dynamic> product) {
    final stockValue = product['stock_qty'] ?? product['quantity'] ?? 0;

    return RetailerProductUiModel(
      id: (product['id'] ?? '').toString(),
      name: (product['name'] ?? 'Product').toString(),
      sku: (product['sku'] ?? '-').toString(),
      category: (product['category'] ?? '-').toString(),
      type: (product['type'] ?? '-').toString(),
      description: (product['description'] ?? '').toString().trim(),
      priceText: (product['price'] ?? '0').toString(),
      stockQty: _toInt(stockValue),
      imageUrl: _productImageUrl(product),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _productImageUrl(Map<String, dynamic> product) {
    final rawValue =
        (product['image_url'] ?? product['imageUrl'] ?? product['image'])
            ?.toString()
            .trim();
    return rawValue == null ? '' : rawValue;
  }
}
