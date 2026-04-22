import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendorlink/screens/wholesaler/products/models/product_ui_model.dart';
import 'package:vendorlink/screens/wholesaler/products/services/product_actions_service.dart';
import 'package:vendorlink/screens/wholesaler/products/widgets/manage_product_sheet.dart';
import 'package:vendorlink/screens/wholesaler/products/widgets/product_form_dialog.dart';
import 'package:vendorlink/screens/wholesaler/products/widgets/product_grid_card.dart';
import 'package:vendorlink/screens/wholesaler/products/widgets/products_empty_state.dart';
import 'package:vendorlink/screens/wholesaler/products/widgets/products_header.dart';
import 'package:vendorlink/screens/wholesaler/products/widgets/wholesaler_product_detail_page.dart';
import 'package:vendorlink/services/auth/auth_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  late final ProductActionsService _productActionsService =
      ProductActionsService(_authService);

  Future<void> _showProductDialog({Map<String, dynamic>? existing}) async {
    await showProductFormDialog(
      context: context,
      actionsService: _productActionsService,
      imagePicker: _imagePicker,
      isMounted: () => mounted,
      existing: existing,
    );
  }

  Future<void> _showManageOptions(Map<String, dynamic> product) async {
    await showManageProductOptions(
      context: context,
      product: product,
      actionsService: _productActionsService,
      isMounted: () => mounted,
      onUpdate: () => _showProductDialog(existing: product),
    );
  }

  Future<void> _showProductDetails(Map<String, dynamic> product) async {
    final item = ProductUiModel.fromMap(product);
    await showWholesalerProductDetails(
      context: context,
      product: item,
      rawProduct: product,
      onManage: () => _showManageOptions(product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _productActionsService.watchCurrentUserProducts(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductsHeader(
                productCount: products.length,
                onAddPressed: () => _showProductDialog(),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildProductsBody(snapshot, products)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsBody(
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
    List<Map<String, dynamic>> products,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Text(
          snapshot.error.toString(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }

    if (products.isEmpty) {
      return const ProductsEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 520 ? 1 : (width < 920 ? 2 : 3);
        final cardHeight = width < 520 ? 355.0 : 330.0;

        return GridView.builder(
          itemCount: products.length,
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            final item = ProductUiModel.fromMap(products[index]);
            return ProductGridCard(
              item: item,
              onTap: () => _showProductDetails(products[index]),
              onManagePressed: () => _showManageOptions(products[index]),
            );
          },
        );
      },
    );
  }
}
