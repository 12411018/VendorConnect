import 'package:flutter/material.dart';

class ProductsHeader extends StatelessWidget {
  const ProductsHeader({
    super.key,
    required this.productCount,
    required this.onAddPressed,
  });

  final int productCount;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Products',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: Text(
                  'Products: $productCount',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onAddPressed,
          icon: const Icon(Icons.add),
          tooltip: 'Add product',
        ),
      ],
    );
  }
}
