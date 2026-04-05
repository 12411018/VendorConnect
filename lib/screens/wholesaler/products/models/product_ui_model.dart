class ProductUiModel {
  const ProductUiModel({
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.sku,
    required this.imageUrl,
    required this.imageUrls,
    required this.ratingAverage,
    required this.ratingCount,
  });

  final String name;
  final String description;
  final String price;
  final String quantity;
  final String sku;
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

  factory ProductUiModel.fromMap(Map<String, dynamic> item) {
    final nameValue = (item['name'] ?? '').toString().trim();
    final descriptionValue = (item['description'] ?? '').toString().trim();
    final skuValue = (item['sku'] ?? '').toString().trim();

    return ProductUiModel(
      name: nameValue.isEmpty ? 'Unnamed Product' : nameValue,
      description: descriptionValue.isEmpty
          ? 'No description'
          : descriptionValue,
      price: (item['price'] ?? '0').toString(),
      quantity: (item['stock_qty'] ?? item['quantity'] ?? 0).toString(),
      sku: skuValue.isEmpty ? '-' : skuValue,
      imageUrl: (item['image_url'] as String?) ?? '',
      imageUrls: _extractImageUrls(item),
      ratingAverage: _extractRatingAverage(item),
      ratingCount: _extractRatingCount(item),
    );
  }

  static List<String> _extractImageUrls(Map<String, dynamic> item) {
    final urls = <String>[];
    final relation = item['product_images'];
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

    final primary = ((item['image_url'] ?? '') as String).trim();
    if (primary.isNotEmpty && !urls.contains(primary)) {
      urls.insert(0, primary);
    }

    return urls;
  }

  static double _extractRatingAverage(Map<String, dynamic> item) {
    final relation = item['product_ratings'];
    if (relation is! List || relation.isEmpty) {
      return 0;
    }

    double sum = 0;
    int count = 0;
    for (final row in relation) {
      if (row is Map<String, dynamic>) {
        final rating = row['rating'];
        final numeric = rating is num
            ? rating.toDouble()
            : double.tryParse('$rating');
        if (numeric != null) {
          sum += numeric;
          count += 1;
        }
      }
    }
    if (count == 0) {
      return 0;
    }
    return sum / count;
  }

  static int _extractRatingCount(Map<String, dynamic> item) {
    final relation = item['product_ratings'];
    if (relation is! List) {
      return 0;
    }
    return relation.whereType<Map<String, dynamic>>().length;
  }
}
