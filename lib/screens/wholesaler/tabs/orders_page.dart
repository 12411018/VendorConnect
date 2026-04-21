import 'package:flutter/material.dart';
import 'package:vendorlink/config/map_config.dart';
import 'package:vendorlink/screens/wholesaler/widgets/order_route_map_screen.dart';
import 'package:vendorlink/services/auth_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const double _katrajLat = MapConfig.marketplaceLat;
  static const double _katrajLng = MapConfig.marketplaceLng;

  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _authService.watchWholesalerOrders(),
      builder: (context, snapshot) {
        final orders = (snapshot.data ?? const <Map<String, dynamic>>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.error.toString()),
            ),
          );
        }

        if (orders.isEmpty) {
          return const Center(child: Text('No incoming orders yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _buildOrderCard(orders[index]),
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = (order['id'] ?? '').toString();
    final orderNumber = (order['order_number'] ?? orderId).toString();
    final status = _effectiveStatus(order);
    final shippingName = (order['shipping_name'] ?? 'Retailer').toString();
    final shippingAddress = (order['shipping_address'] ?? '-').toString();
    final totalAmount = (order['total_amount'] ?? 0).toString();
    final items = _extractOrderItems(order);

    final paymentLat = _toDoubleOrNull(order['payment_lat']) ?? _katrajLat;
    final paymentLng = _toDoubleOrNull(order['payment_lng']) ?? _katrajLng;
    final marketplaceLat =
        _toDoubleOrNull(order['marketplace_lat']) ?? _katrajLat;
    final marketplaceLng =
        _toDoubleOrNull(order['marketplace_lng']) ?? _katrajLng;

    final statusColor = switch (status) {
      'pending' => const Color(0xFF1D4ED8),
      'accepted' => const Color(0xFFEA580C),
      'processing' => const Color(0xFFEA580C),
      'delivered' => const Color(0xFF16A34A),
      'rejected' => const Color(0xFFB91C1C),
      _ => const Color(0xFF334155),
    };

    final statusLabel = switch (status) {
      'pending' => 'Order Placed',
      'accepted' => 'Out for Delivery',
      'processing' => 'Out for Delivery',
      'delivered' => 'Delivered',
      'rejected' => 'Rejected',
      _ => status,
    };

    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Retailer: $shippingName'),
            const SizedBox(height: 2),
            Text(
              shippingAddress,
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ₹$totalAmount',
              style: const TextStyle(
                color: Color(0xFF93C5FD),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Items', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.take(3).map((item) {
              final image = _itemImage(item);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: image.isEmpty
                          ? Container(
                              width: 34,
                              height: 34,
                              color: const Color(0xFF1E293B),
                              child: const Icon(Icons.image_outlined, size: 16),
                            )
                          : Image.network(
                              image,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 34,
                                height: 34,
                                color: const Color(0xFF1E293B),
                                child: const Icon(Icons.broken_image, size: 16),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _itemLabel(item),
                        style: const TextStyle(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (items.length > 3)
              Text(
                '+ ${items.length - 3} more items',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderRouteMapScreen(
                      paymentLat: paymentLat,
                      paymentLng: paymentLng,
                      marketplaceLat: marketplaceLat,
                      marketplaceLng: marketplaceLng,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open Live Delivery Map'),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _authService.updateOrderStatusForWholesaler(
                      orderId: orderId,
                      status: 'processing',
                    );
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order moved to out for delivery.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Mark Out For Delivery'),
                ),
              ),
            ],
            if (status == 'processing' || status == 'accepted') ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: const Text(
                  'Waiting for retailer confirmation to mark as delivered.',
                  style: TextStyle(color: Color(0xFFD1D5DB)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _extractOrderItems(Map<String, dynamic> order) {
    final rawItems = order['order_items'];
    if (rawItems is List) {
      return rawItems.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return const [];
  }

  String _itemImage(Map<String, dynamic> item) {
    final product = item['product'];
    if (product is Map<String, dynamic>) {
      return (product['image_url'] ?? '').toString().trim();
    }
    return (item['image_url'] ?? '').toString().trim();
  }

  String _itemLabel(Map<String, dynamic> item) {
    final product = item['product'];
    final productName = product is Map<String, dynamic>
        ? (product['name'] ?? 'Product').toString()
        : (item['product_name'] ?? 'Product').toString();
    final quantity = (item['quantity'] ?? 1).toString();
    final price = (item['unit_price'] ?? item['price'] ?? 0).toString();
    return '$productName x$quantity • ₹$price';
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString());
  }

  String _effectiveStatus(Map<String, dynamic> order) {
    final confirmedAt = (order['retailer_confirmed_at'] ?? '')
        .toString()
        .trim();
    if (confirmedAt.isNotEmpty) {
      return 'delivered';
    }

    final raw = (order['status'] ?? 'pending').toString().toLowerCase();
    if (raw == 'completed' || raw == 'fulfilled' || raw == 'done') {
      return 'delivered';
    }
    return raw;
  }
}
