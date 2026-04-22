import 'package:flutter/material.dart';

import 'package:vendorlink/screens/wholesaler/products/models/product_ui_model.dart';

class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onManagePressed,
  });

  final ProductUiModel item;
  final VoidCallback onTap;
  final VoidCallback onManagePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stockQty = int.tryParse(item.quantity) ?? 0;
    final isOutOfStock = stockQty <= 0;

    return Opacity(
      opacity: isOutOfStock ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 178,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF111827)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: item.imageUrl.isEmpty
                              ? Container(
                                  color: const Color(0xFF374151),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white70,
                                  ),
                                )
                              : Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFF374151),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC111827),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF374151)),
                          ),
                          child: Text(
                            isOutOfStock ? 'Sold out' : 'Qty: ${item.quantity}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF9FAFB),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Price: ${item.price}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 34,
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: onManagePressed,
                            icon: const Icon(Icons.more_horiz, size: 16),
                            label: const Text('Manage'),
                            style: FilledButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

