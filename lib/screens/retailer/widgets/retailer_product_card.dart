import 'package:flutter/material.dart';

import 'package:vendorlink/screens/retailer/models/retailer_product_ui_model.dart';

class RetailerProductCard extends StatelessWidget {
  const RetailerProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
  });

  final RetailerProductUiModel product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: product.isOutOfStock ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF101827),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: product.imageUrl.isEmpty
                          ? _ProductImagePlaceholder(name: product.name)
                          : Container(
                              color: const Color(0xFF0B1220),
                              alignment: Alignment.center,
                              child: Image.network(
                                product.imageUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) {
                                  return _ProductImagePlaceholder(
                                      name: product.name);
                                },
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '₹${product.formattedPrice}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ProductMetaChip(
                        label: product.vendorName.isEmpty
                            ? 'Wholesaler'
                            : product.vendorName,
                        icon: Icons.person_outline,
                      ),
                      if (product.vendorShopName.trim().isNotEmpty)
                        _ProductMetaChip(
                          label: product.vendorShopName,
                          icon: Icons.storefront_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ProductMetaChip(
                        label: product.stockLabel,
                        icon: Icons.inventory_2_outlined,
                      ),
                      if (product.category.trim().isNotEmpty &&
                          product.category != '-')
                        _ProductMetaChip(
                          label: product.category,
                          icon: Icons.category_outlined,
                        ),
                      if (product.type.trim().isNotEmpty && product.type != '-')
                        _ProductMetaChip(
                          label: product.type,
                          icon: Icons.sell_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isEmpty
                        ? 'No description added for this product.'
                        : product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      height: 1.3,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: product.isOutOfStock ? null : onAddToCart,
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: Text(
                        product.isOutOfStock ? 'Out of stock' : 'Add to cart',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder({required this.name});

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


class _ProductMetaChip extends StatelessWidget {
  const _ProductMetaChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

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
