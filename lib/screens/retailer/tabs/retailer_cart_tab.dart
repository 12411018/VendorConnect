import 'package:flutter/material.dart';

class RetailerCartTab extends StatelessWidget {
  const RetailerCartTab({
    super.key,
    required this.cart,
    required this.cartProducts,
    required this.isPlacingOrder,
    required this.onIncrement,
    required this.onDecrement,
    required this.onPlaceOrder,
  });

  final Map<String, int> cart;
  final Map<String, Map<String, dynamic>> cartProducts;
  final bool isPlacingOrder;
  final void Function(String productId) onIncrement;
  final void Function(String productId) onDecrement;
  final Future<void> Function() onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const Center(child: Text('Your cart is empty.'));
    }

    final cartEntries = cart.entries.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cartEntries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = cartEntries[index];
              final product = cartProducts[entry.key] ?? const {};
              final name = (product['name'] ?? 'Product').toString();
              final price = (product['price'] ?? '0').toString();
              final imageUrl = _productImageUrl(product);

              return Card(
                color: const Color(0xFF111827),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 58,
                      height: 58,
                      color: const Color(0xFF1E293B),
                      child: imageUrl.isEmpty
                          ? const Icon(
                              Icons.image_outlined,
                              color: Color(0xFF94A3B8),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_outlined,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(color: Color(0xFFF8FAFC)),
                  ),
                  subtitle: Text(
                    'Price: ₹$price',
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => onDecrement(entry.key),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${entry.value}'),
                      IconButton(
                        onPressed: () => onIncrement(entry.key),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPlacingOrder ? null : onPlaceOrder,
              icon: isPlacingOrder
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_bag_outlined),
              label: Text(isPlacingOrder ? 'Placing...' : 'Place Order'),
            ),
          ),
        ),
      ],
    );
  }
}

String _productImageUrl(Map<String, dynamic> product) {
  final rawValue =
      product['image_url'] ?? product['imageUrl'] ?? product['image'];
  return rawValue == null ? '' : rawValue.toString().trim();
}
