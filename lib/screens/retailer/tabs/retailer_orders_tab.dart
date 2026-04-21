import 'package:flutter/material.dart';
import 'package:vendorlink/config/map_config.dart';
import 'package:vendorlink/screens/retailer/widgets/retailer_order_status_chip.dart';
import 'package:vendorlink/screens/wholesaler/widgets/order_route_map_screen.dart';
import 'package:vendorlink/services/auth_service.dart';

class RetailerOrdersTab extends StatefulWidget {
  const RetailerOrdersTab({super.key});

  @override
  State<RetailerOrdersTab> createState() => _RetailerOrdersTabState();
}

class _RetailerOrdersTabState extends State<RetailerOrdersTab> {
  static const double _marketplaceLat = MapConfig.marketplaceLat;
  static const double _marketplaceLng = MapConfig.marketplaceLng;

  final AuthService _authService = AuthService();
  late final Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = _authService.watchRetailerOrders();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const [];

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
          return const Center(child: Text('No orders placed yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderNumber = (order['order_number'] ?? order['id'] ?? '-')
        .toString();
    final shippingName = (order['shipping_name'] ?? 'Retailer').toString();
    final profileLocation = (order['retailer_location'] ?? '')
        .toString()
        .trim();
    final shippingAddress = profileLocation.isNotEmpty
        ? profileLocation
        : (order['shipping_address'] ?? 'Address not available').toString();
    final wholesalerName = (order['vendor_name'] ?? 'Wholesaler').toString();
    final wholesalerPhone = (order['vendor_phone'] ?? '').toString().trim();
    final status = (order['status'] ?? 'pending').toString();
    final normalizedStatus = status.toLowerCase();
    final totalAmount =
        (order['total_amount'] ?? order['total_price'] ?? 0).toString();
    final items = _extractOrderItems(order);
    final orderId = (order['id'] ?? '').toString();

    final paymentLat =
        _toDoubleOrNull(order['payment_lat']) ?? _marketplaceLat;
    final paymentLng =
        _toDoubleOrNull(order['payment_lng']) ?? _marketplaceLng;
    final orderMarketplaceLat =
        _toDoubleOrNull(order['marketplace_lat']) ?? _marketplaceLat;
    final orderMarketplaceLng =
        _toDoubleOrNull(order['marketplace_lng']) ?? _marketplaceLng;

    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$orderNumber',
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deliver to: $shippingName',
                        style: const TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                      Text(
                        shippingAddress,
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Wholesaler: $wholesalerName',
                        style: const TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                      Text(
                        wholesalerPhone.isEmpty
                            ? 'Contact: Not available'
                            : 'Contact: $wholesalerPhone',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                RetailerOrderStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total amount: ₹$totalAmount',
              style: const TextStyle(
                color: Color(0xFF93C5FD),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (items.isNotEmpty) ...[
              const Text(
                'Items',
                style: TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...items
                  .take(4)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _OrderItemThumb(imageUrl: _itemImageUrl(item)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _formatItemLabel(item),
                              style: const TextStyle(
                                color: Color(0xFFD1D5DB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (items.length > 4)
                Text(
                  '+ ${items.length - 4} more items',
                  style: const TextStyle(color: Color(0xFF9CA3AF)),
                ),
            ],
            const SizedBox(height: 12),
            _buildOrderMessage(status),
            const SizedBox(height: 8),
            if (normalizedStatus != 'rejected')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderRouteMapScreen(
                          paymentLat: paymentLat,
                          paymentLng: paymentLng,
                          marketplaceLat: orderMarketplaceLat,
                          marketplaceLng: orderMarketplaceLng,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Track Delivery on Map'),
                ),
              ),
            if (normalizedStatus == 'processing' ||
                normalizedStatus == 'accepted')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: orderId.isEmpty
                      ? null
                      : () => _confirmDelivery(orderId),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Delivery Received'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelivery(String orderId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authService.updateOrderStatusForRetailer(
        orderId: orderId,
        status: 'delivered',
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Delivery marked as completed.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Confirmation failed: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }
}

// ─── Private widgets ───

class _OrderItemThumb extends StatelessWidget {
  const _OrderItemThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        color: const Color(0xFF1E293B),
        child: imageUrl.isEmpty
            ? const Icon(
                Icons.image_outlined,
                size: 20,
                color: Color(0xFF94A3B8),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ),
      ),
    );
  }
}

// ─── Helper functions ───

double? _toDoubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString());
}

List<Map<String, dynamic>> _extractOrderItems(Map<String, dynamic> order) {
  final rawItems = order['order_items'];
  if (rawItems is List) {
    return rawItems.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  final productName = (order['product_name'] ?? order['name'] ?? '').toString();
  if (productName.isEmpty) return const [];

  return <Map<String, dynamic>>[
    {
      'product_name': productName,
      'quantity': order['quantity'] ?? 1,
      'price': order['total_price'] ?? order['unit_price'] ?? 0,
      'total_price': order['total_price'] ?? order['total_amount'] ?? 0,
      'sku': order['sku'] ?? '-',
      'category': order['category'] ?? '-',
      'type': order['type'] ?? '-',
    },
  ];
}

String _formatItemLabel(Map<String, dynamic> item) {
  final product = item['product'];
  final productName = product is Map<String, dynamic>
      ? (product['name'] ?? 'Product').toString()
      : (item['product_name'] ?? 'Product').toString();
  final quantity = _toDoubleOrNull(item['quantity'])?.toInt() ?? 1;
  final unitPrice = _itemUnitPrice(item);
  return '$productName x$quantity • ₹${_formatRupees(unitPrice)}';
}

double _itemUnitPrice(Map<String, dynamic> item) {
  final product = item['product'];
  final quantity = _toDoubleOrNull(item['quantity'])?.toInt() ?? 1;

  final totalPrice = _toDoubleOrNull(item['total_price']);
  if (totalPrice != null && quantity > 0) {
    final derived = totalPrice / quantity;
    if (derived > 0) return derived;
  }

  final candidates = <dynamic>[
    item['unit_price'],
    item['price'],
    if (product is Map<String, dynamic>) product['price'],
    if (product is Map<String, dynamic>) product['selling_price'],
    if (product is Map<String, dynamic>) product['mrp'],
  ];

  for (final candidate in candidates) {
    final value = _toDoubleOrNull(candidate);
    if (value != null && value > 0) return value;
  }

  return 0;
}

String _formatRupees(double amount) {
  if (amount == amount.truncateToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String _itemImageUrl(Map<String, dynamic> item) {
  final product = item['product'];
  if (product is Map<String, dynamic>) {
    final fromProduct =
        (product['image_url'] ?? product['imageUrl'] ?? product['image'])
            .toString()
            .trim();
    if (fromProduct.isNotEmpty) return fromProduct;
  }

  final fallback = (item['image_url'] ?? item['imageUrl'] ?? item['image'])
      .toString()
      .trim();
  return fallback.isEmpty ? '' : fallback;
}

Widget _buildOrderMessage(String status) {
  final normalized = status.toLowerCase();
  if (normalized == 'delivered' ||
      normalized == 'completed' ||
      normalized == 'fulfilled' ||
      normalized == 'done') {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF14532D)),
      ),
      child: const Text(
        'Order delivered successfully.',
        style: TextStyle(color: Color(0xFF86EFAC), fontWeight: FontWeight.w600),
      ),
    );
  }

  if (normalized == 'processing') {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C2D12)),
      ),
      child: const Text(
        'Out for delivery. Track live route on map.',
        style: TextStyle(color: Color(0xFFFED7AA), fontWeight: FontWeight.w600),
      ),
    );
  }

  if (normalized == 'accepted') {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1D4ED8)),
      ),
      child: const Text(
        'Order accepted. You will get it soon.',
        style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.w600),
      ),
    );
  }

  if (normalized == 'rejected') {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7F1D1D)),
      ),
      child: const Text(
        'Order canceled by wholesaler.',
        style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w600),
      ),
    );
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF374151)),
    ),
    child: const Text(
      'Waiting for wholesaler response.',
      style: TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w600),
    ),
  );
}
