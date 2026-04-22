import 'package:flutter/material.dart';

import 'package:vendorlink/screens/wholesaler/products/models/product_ui_model.dart';
import 'package:vendorlink/services/date_time_service.dart';

Future<void> showWholesalerProductDetails({
  required BuildContext context,
  required ProductUiModel product,
  required Map<String, dynamic> rawProduct,
  required VoidCallback onManage,
}) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _WholesalerProductDetailPage(
        product: product,
        rawProduct: rawProduct,
        onManage: onManage,
      ),
    ),
  );
}

class _WholesalerProductDetailPage extends StatelessWidget {
  const _WholesalerProductDetailPage({
    required this.product,
    required this.rawProduct,
    required this.onManage,
  });

  final ProductUiModel product;
  final Map<String, dynamic> rawProduct;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final category = (rawProduct['category'] ?? '-').toString().trim();
    final type = (rawProduct['type'] ?? '-').toString().trim();
    final sku = product.sku.trim().isEmpty ? '-' : product.sku.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1120),
        foregroundColor: const Color(0xFFF8FAFC),
        title: const Text('Product Details'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onManage();
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Manage'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 220, maxHeight: 340),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: product.imageUrl.isEmpty
                  ? _ImagePlaceholder(name: product.name)
                  : Container(
                      color: const Color(0xFF0B1220),
                      alignment: Alignment.center,
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            _ImagePlaceholder(name: product.name),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Price: ₹${product.price}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF60A5FA),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.inventory_2_outlined,
                label: 'Stock ${product.quantity}',
              ),
              _MetaChip(
                icon: Icons.confirmation_number_outlined,
                label: 'SKU $sku',
              ),
              if (category.isNotEmpty && category != '-')
                _MetaChip(icon: Icons.category_outlined, label: category),
              if (type.isNotEmpty && type != '-')
                _MetaChip(icon: Icons.sell_outlined, label: type),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.description,
            style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFCBD5F5)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFCBD5F5), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

