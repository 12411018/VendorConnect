import 'package:flutter/material.dart';

import 'package:vendorlink/screens/retailer/models/retailer_product_ui_model.dart';

Future<void> showRetailerProductDetails({
  required BuildContext context,
  required RetailerProductUiModel product,
  required VoidCallback? onAddToCart,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Product details',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => Align(
      alignment: Alignment.bottomCenter,
      child: RetailerProductDetailPage(
        product: product,
        onAddToCart: onAddToCart,
      ),
    ),
  );
}

class RetailerProductDetailPage extends StatelessWidget {
  const RetailerProductDetailPage({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  final RetailerProductUiModel product;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final displayName = product.name.trim().isEmpty
        ? 'Unnamed Product'
        : product.name.trim();
    final displayDescription = product.description.trim().isEmpty
        ? 'No description provided for this product.'
        : product.description.trim();
    final displayPrice = product.formattedPrice.trim().isEmpty
        ? '0'
        : product.formattedPrice.trim();

    final displayVendorName = product.vendorName.trim().isEmpty
        ? 'Wholesaler'
        : product.vendorName.trim();
    final displayShopName = product.vendorShopName.trim();
    final displayPhone = product.vendorPhone.trim();

    return SafeArea(
      top: false,
      child: Material(
        color: const Color(0xFF0B1120),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: const Color(0xFFF8FAFC),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1F2937), height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 220,
                        maxHeight: 280,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: product.imageUrl.isEmpty
                            ? _ImagePlaceholder(name: displayName)
                            : Container(
                                color: const Color(0xFF0B1220),
                                alignment: Alignment.center,
                                child: Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) =>
                                      _ImagePlaceholder(name: displayName),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Price: Rs $displayPrice',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Wholesaler: $displayVendorName',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (displayShopName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Shop: $displayShopName',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      displayPhone.isNotEmpty
                          ? 'Contact: $displayPhone'
                          : 'Contact: Not available',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MetaChip(
                      icon: Icons.inventory_2_outlined,
                      label: product.stockLabel,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayDescription,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: product.isOutOfStock
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onAddToCart?.call();
                            },
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: Text(
                        product.isOutOfStock ? 'Out of stock' : 'Add to cart',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

