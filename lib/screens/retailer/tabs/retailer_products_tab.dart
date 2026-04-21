import 'package:flutter/material.dart';
import 'package:vendorlink/screens/retailer/models/retailer_cart.dart';
import 'package:vendorlink/screens/retailer/models/retailer_product_ui_model.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_product_card.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_product_detail_sheet.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_products_empty_state.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_products_header.dart';
import 'package:vendorlink/services/auth_service.dart';

class RetailerProductsTab extends StatefulWidget {
  const RetailerProductsTab({super.key, required this.cart});

  final RetailerCart cart;

  @override
  State<RetailerProductsTab> createState() => _RetailerProductsTabState();
}

class _RetailerProductsTabState extends State<RetailerProductsTab> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _productsStream;

  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _typeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _productsStream = _authService.watchMarketplaceProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <Map<String, dynamic>>[];
        final categories = _extractFilterOptions(products, 'category');
        final types = _extractFilterOptions(products, 'type');
        final effectiveCategory = categories.contains(_categoryFilter)
            ? _categoryFilter
            : 'All';
        final effectiveType = types.contains(_typeFilter) ? _typeFilter : 'All';
        final filtered = _filterProducts(
          products,
          selectedCategory: effectiveCategory,
          selectedType: effectiveType,
          searchQuery: _searchQuery,
        );
        final hasActiveFilters =
            _searchQuery.isNotEmpty ||
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
            onRefresh: () => _authService.fetchMarketplaceProducts(),
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
                searchController: _searchController,
                categoryValue: effectiveCategory,
                categoryOptions: categories,
                typeValue: effectiveType,
                typeOptions: types,
                onSearchChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                onCategoryChanged: (value) {
                  setState(() {
                    _categoryFilter = value;
                  });
                },
                onTypeChanged: (value) {
                  setState(() {
                    _typeFilter = value;
                  });
                },
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
        _searchQuery.isNotEmpty ||
        _categoryFilter != 'All' ||
        _typeFilter != 'All';
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
                    onTap: () => _openProductDetails(product),
                    onAddToCart: productId.isEmpty
                        ? null
                        : () => _addToCart(product),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openProductDetails(Map<String, dynamic> product) async {
    final productModel = RetailerProductUiModel.fromMap(product);
    await showRetailerProductDetails(
      context: context,
      product: productModel,
      onAddToCart: () => _addToCart(product),
      onRate: (rating, review) async {
        await _authService.submitProductRating(
          productId: productModel.id,
          rating: rating,
          review: review,
        );
      },
    );
  }

  void _addToCart(Map<String, dynamic> product) {
    final productId = (product['id'] ?? '').toString();
    if (productId.isEmpty) return;

    if (RetailerProductUiModel.fromMap(product).stockQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is out of stock.')),
      );
      return;
    }

    widget.cart.addToCart(productId, product);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart.')),
    );
  }
}

// ─── Helper functions ───

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
