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
    required this.imageUrls,
    required this.ratingAverage,
    required this.ratingCount,
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
  final List<String> imageUrls;
  final double ratingAverage;
  final int ratingCount;

  List<String> get galleryImages {
    if (imageUrls.isNotEmpty) {
      return imageUrls;
    }
    if (imageUrl.trim().isNotEmpty) {
      return [imageUrl.trim()];
    }
    return const [];
  }

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
      imageUrls: _productImageUrls(product),
      ratingAverage: _ratingAverage(product),
      ratingCount: _ratingCount(product),
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

  static List<String> _productImageUrls(Map<String, dynamic> product) {
    final urls = <String>[];

    final relation = product['product_images'];
    if (relation is List) {
      for (final row in relation) {
        if (row is Map<String, dynamic>) {
          final url = (row['image_url'] ?? '').toString().trim();
          if (url.isNotEmpty) {
            urls.add(url);
          }
        }
      }
    }

    final fallbackImage = _productImageUrl(product).trim();
    if (fallbackImage.isNotEmpty && !urls.contains(fallbackImage)) {
      urls.insert(0, fallbackImage);
    }

    return urls;
  }

  static double _ratingAverage(Map<String, dynamic> product) {
    final ratings = product['product_ratings'];
    if (ratings is! List || ratings.isEmpty) {
      return 0;
    }

    double sum = 0;
    int count = 0;
    for (final row in ratings) {
      if (row is Map<String, dynamic>) {
        final raw = row['rating'];
        final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
        if (value != null) {
          sum += value;
          count += 1;
        }
      }
    }
    if (count == 0) {
      return 0;
    }
    return sum / count;
  }

  static int _ratingCount(Map<String, dynamic> product) {
    final ratings = product['product_ratings'];
    if (ratings is! List) {
      return 0;
    }
    return ratings.whereType<Map<String, dynamic>>().length;
  }
}
