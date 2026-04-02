import 'package:flutter/material.dart';
import 'package:vendorlink/services/auth_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final AuthService _authService = AuthService();

  Future<void> _updateStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      await _authService.updateOrderStatusForWholesaler(
        orderId: orderId,
        status: status,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order $status.')),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _authService.watchWholesalerOrders(),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const [];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (orders.isEmpty) {
          return const Center(child: Text('No incoming orders yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderId = (order['id'] ?? '').toString();
            final productName =
                (order['product_name'] ?? order['name'] ?? 'Product').toString();
            final quantity = (order['quantity'] ?? 0).toString();
            final retailer =
                (order['retailer_id'] ?? order['retailer'] ?? '-').toString();
            final totalPrice =
                (order['total_price'] ?? order['price'] ?? '-').toString();
            final status = (order['status'] ?? 'pending').toString();
            final isPending = status.toLowerCase() == 'pending';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Retailer: $retailer'),
                    Text('Quantity: $quantity  |  Total: $totalPrice'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _OrderStatusChip(status: status),
                        const Spacer(),
                        if (isPending)
                          TextButton.icon(
                            onPressed: orderId.isEmpty
                                ? null
                                : () =>
                                      _updateStatus(orderId: orderId, status: 'rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        if (isPending)
                          const SizedBox(width: 8),
                        if (isPending)
                          ElevatedButton.icon(
                            onPressed: orderId.isEmpty
                                ? null
                                : () =>
                                      _updateStatus(orderId: orderId, status: 'accepted'),
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color background;
    switch (normalized) {
      case 'accepted':
        background = const Color(0xFF14532D);
        break;
      case 'rejected':
        background = const Color(0xFF7F1D1D);
        break;
      case 'delivered':
        background = const Color(0xFF1E3A8A);
        break;
      default:
        background = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
