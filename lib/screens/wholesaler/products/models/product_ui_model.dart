class ProductUiModel {
  const ProductUiModel({
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.sku,
    required this.imageUrl,
  });

  final String name;
  final String description;
  final String price;
  final String quantity;
  final String sku;
  final String imageUrl;

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
    );
  }
}
