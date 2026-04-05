import 'package:flutter/material.dart';

import 'package:vendorlink/screens/retailer/models/retailer_product_ui_model.dart';

Future<void> showRetailerProductDetails({
  required BuildContext context,
  required RetailerProductUiModel product,
  required VoidCallback? onAddToCart,
  required Future<void> Function(int rating, String review) onRate,
}) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _RetailerProductDetailsPage(
        product: product,
        onAddToCart: onAddToCart,
        onRate: onRate,
      ),
    ),
  );
}

class _RetailerProductDetailsPage extends StatelessWidget {
  const _RetailerProductDetailsPage({
    required this.product,
    required this.onAddToCart,
    required this.onRate,
  });

  final RetailerProductUiModel product;
  final VoidCallback? onAddToCart;
  final Future<void> Function(int rating, String review) onRate;

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
    final ratingAverage = product.ratingAverage.isFinite
        ? product.ratingAverage
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1120),
        foregroundColor: const Color(0xFFF8FAFC),
        title: const Text('Product Details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 220, maxHeight: 340),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: product.galleryImages.isEmpty
                    ? _ProductImagePlaceholder(name: displayName)
                    : _ProductImageCarousel(
                        imageUrls: product.galleryImages,
                        fallbackName: displayName,
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
              '₹$displayPrice',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProductMetaChip(
                  label: product.stockLabel,
                  icon: Icons.inventory_2_outlined,
                ),
                if (product.sku.trim().isNotEmpty && product.sku != '-')
                  _ProductMetaChip(
                    label: 'SKU ${product.sku}',
                    icon: Icons.confirmation_number_outlined,
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Text(
                  '${ratingAverage.toStringAsFixed(1)} (${product.ratingCount} ratings)',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _showRateDialog(context, onRate);
                  },
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Rate'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayDescription,
              style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.45),
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
    );
  }
}

Future<void> _showRateDialog(
  BuildContext context,
  Future<void> Function(int rating, String review) onRate,
) async {
  final reviewController = TextEditingController();
  var stars = 5;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rate this product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final selected = index < stars;
                    return IconButton(
                      onPressed: () => setState(() => stars = index + 1),
                      icon: Icon(
                        selected
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: reviewController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Review (optional)',
                    hintText: 'How was the quality and delivery?',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await onRate(stars, reviewController.text.trim());
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );

  reviewController.dispose();
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

class _ProductImageCarousel extends StatefulWidget {
  const _ProductImageCarousel({
    required this.imageUrls,
    required this.fallbackName,
  });

  final List<String> imageUrls;
  final String fallbackName;

  @override
  State<_ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<_ProductImageCarousel> {
  final PageController _controller = PageController(viewportFraction: 1);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.imageUrls.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) {
            return Image.network(
              widget.imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return _ProductImagePlaceholder(name: widget.fallbackName);
              },
            );
          },
        ),
        if (widget.imageUrls.length > 1)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_index + 1}/${widget.imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
