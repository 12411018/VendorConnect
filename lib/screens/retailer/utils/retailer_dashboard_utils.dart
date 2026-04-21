double? toDoubleOrNull(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '').toString());
}

List<Map<String, dynamic>> extractOrderItems(Map<String, dynamic> order) {
  final rawItems = order['order_items'];
  if (rawItems is List) {
    return rawItems.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  final productName = (order['product_name'] ?? order['name'] ?? '').toString();
  if (productName.isEmpty) {
    return const [];
  }

  return <Map<String, dynamic>>[
    {
      'product_name': productName,
      'quantity': order['quantity'] ?? 1,
      'price': order['total_price'] ?? order['unit_price'] ?? 0,
      'total_price': order['total_price'] ?? order['total_amount'] ?? 0,
      'sku': order['sku'] ?? '-',
      'category': order['category'] ?? '-',
      'type': order['type'] ?? '-',
    },
  ];
}

String formatItemLabel(Map<String, dynamic> item) {
  final product = item['product'];
  final productName = product is Map<String, dynamic>
      ? (product['name'] ?? 'Product').toString()
      : (item['product_name'] ?? 'Product').toString();
  final quantity = (item['quantity'] ?? 1).toString();
  final price = (item['price'] ?? item['total_price'] ?? 0).toString();
  return '$productName x$quantity • ₹$price';
}

List<String> extractFilterOptions(
  List<Map<String, dynamic>> products,
  String field,
) {
  final values = <String>{'All'};
  for (final product in products) {
    final entry = (product[field] ?? '').toString().trim();
    if (entry.isNotEmpty) {
      values.add(entry);
    }
  }
  return values.toList();
}

List<Map<String, dynamic>> filterProducts(
  List<Map<String, dynamic>> products, {
  required String selectedCategory,
  required String selectedType,
  required String searchQuery,
}) {
  final normalizedSearch = searchQuery.trim().toLowerCase();
  final requestedCategory = selectedCategory.trim().toLowerCase();
  final requestedType = selectedType.trim().toLowerCase();

  return products.where((product) {
    final name = (product['name'] ?? '').toString().toLowerCase();
    final sku = (product['sku'] ?? '').toString().toLowerCase();
    final category = (product['category'] ?? '').toString().trim().toLowerCase();
    final type = (product['type'] ?? '').toString().trim().toLowerCase();

    final matchesSearch =
        normalizedSearch.isEmpty ||
        name.contains(normalizedSearch) ||
        sku.contains(normalizedSearch);
    final matchesCategory =
        requestedCategory == 'all' || category == requestedCategory;
    final matchesType = requestedType == 'all' || type == requestedType;

    return matchesSearch && matchesCategory && matchesType;
  }).toList();
}
