import 'package:flutter/material.dart';
import 'package:vendorlink/screens/retailer/models/retailer_product_ui_model.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_product_card.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_products_empty_state.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_products_header.dart';

class RetailerProductsTab extends StatelessWidget {
  const RetailerProductsTab({
    super.key,
    required this.productsStream,
    required this.searchController,
    required this.searchQuery,
    required this.categoryFilter,
    required this.typeFilter,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onRefresh,
    required this.onOpenProductDetails,
    required this.onAddToCart,
  });

  final Stream<List<Map<String, dynamic>>> productsStream;
  final TextEditingController searchController;
  final String searchQuery;
  final String categoryFilter;
  final String typeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onTypeChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic> product)
  onOpenProductDetails;
  final void Function(Map<String, dynamic> product) onAddToCart;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: productsStream,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <Map<String, dynamic>>[];
        final categories = _extractFilterOptions(products, 'category');
        final types = _extractFilterOptions(products, 'type');
        final effectiveCategory = categories.contains(categoryFilter)
            ? categoryFilter
            : 'All';
        final effectiveType = types.contains(typeFilter) ? typeFilter : 'All';
        final filtered = _filterProducts(
          products,
          selectedCategory: effectiveCategory,
          selectedType: effectiveType,
          searchQuery: searchQuery,
        );
        final hasActiveFilters =
            searchQuery.isNotEmpty ||
            effectiveCategory != 'All' ||
            effectiveType != 'All';
        final visibleProducts =
            !hasActiveFilters && filtered.isEmpty && products.isNotEmpty
            ? products
            : filtered;
        final summaryText =
            snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData
            ? 'Loading products...'
            : 'Showing ${visibleProducts.length} product${visibleProducts.length == 1 ? '' : 's'}';

        Widget content;
        if (snapshot.hasError) {
          content = Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.error.toString()),
            ),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting &&
            products.isEmpty) {
          content = const Center(child: CircularProgressIndicator());
        } else {
          content = RefreshIndicator(
            onRefresh: onRefresh,
            child: _buildProductList(products, visibleProducts),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: RetailerProductsHeader(
                summaryText: summaryText,
                productCount: visibleProducts.length,
                searchController: searchController,
                categoryValue: effectiveCategory,
                categoryOptions: categories,
                typeValue: effectiveType,
                typeOptions: types,
                onSearchChanged: onSearchChanged,
                onCategoryChanged: onCategoryChanged,
                onTypeChanged: onTypeChanged,
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _buildProductList(
    List<Map<String, dynamic>> allProducts,
    List<Map<String, dynamic>> visibleProducts,
  ) {
    final hasFilters =
        searchQuery.isNotEmpty ||
        categoryFilter != 'All' ||
        typeFilter != 'All';
    final productsToRender = visibleProducts.isNotEmpty
        ? visibleProducts
        : allProducts;

    if (allProducts.isEmpty) {
      return const RetailerProductsEmptyState();
    }

    return Column(
      children: [
        if (hasFilters && visibleProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No exact matches for the current filters. Showing all products so you can verify the data.',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1100
                  ? 3
                  : width >= 720
                  ? 2
                  : 1;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: crossAxisCount == 1 ? 470 : 520,
                ),
                itemCount: productsToRender.length,
                itemBuilder: (context, index) {
                  final product = productsToRender[index];
                  final productId = (product['id'] ?? '').toString();
                  final productModel = RetailerProductUiModel.fromMap(product);
                  return RetailerProductCard(
                    product: productModel,
                    onTap: () => _handleOpenProductDetails(context, product),
                    onAddToCart: productId.isEmpty
                        ? null
                        : () => _handleAddToCart(context, product),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleOpenProductDetails(
    BuildContext context,
    Map<String, dynamic> product,
  ) async {
    await onOpenProductDetails(product);
  }

  void _handleAddToCart(BuildContext context, Map<String, dynamic> product) {
    onAddToCart(product);
  }
}

List<String> _extractFilterOptions(
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

List<Map<String, dynamic>> _filterProducts(
  List<Map<String, dynamic>> products, {
  required String selectedCategory,
  required String selectedType,
  required String searchQuery,
}) {
  return products.where((product) {
    final name = (product['name'] ?? '').toString().toLowerCase();
    final sku = (product['sku'] ?? '').toString().toLowerCase();
    final category = (product['category'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final type = (product['type'] ?? '').toString().trim().toLowerCase();
    final requestedCategory = selectedCategory.trim().toLowerCase();
    final requestedType = selectedType.trim().toLowerCase();
    final normalizedSearch = searchQuery.trim().toLowerCase();

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
