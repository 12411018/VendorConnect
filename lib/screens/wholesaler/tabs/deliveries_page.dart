import 'package:flutter/material.dart';
import 'package:vendorlink/config/map_config.dart';
import 'package:vendorlink/screens/wholesaler/widgets/order_route_map_screen.dart';
import 'package:vendorlink/services/auth_service.dart';

class DeliveriesPage extends StatelessWidget {
  const DeliveriesPage({super.key});

  static const double _katrajLat = MapConfig.marketplaceLat;
  static const double _katrajLng = MapConfig.marketplaceLng;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: authService.watchWholesalerOrders(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final active = all
            .where((e) {
              final status = _effectiveStatus(e);
              return status == 'pending' ||
                  status == 'processing' ||
                  status == 'accepted';
            })
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

        if (active.isEmpty) {
          return const Center(
            child: Text(
              'No active deliveries. New dispatches will appear here.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: active.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final order = active[index];
            final orderNumber = (order['order_number'] ?? order['id'] ?? '-')
                .toString();
            final shippingName = (order['shipping_name'] ?? 'Retailer')
                .toString();
            final status = _effectiveStatus(order);
            final paymentLat =
                _toDoubleOrNull(order['payment_lat']) ?? _katrajLat;
            final paymentLng =
                _toDoubleOrNull(order['payment_lng']) ?? _katrajLng;
            final marketLat =
                _toDoubleOrNull(order['marketplace_lat']) ?? _katrajLat;
            final marketLng =
                _toDoubleOrNull(order['marketplace_lng']) ?? _katrajLng;

            final etaMinutes = status == 'processing'
                ? 14 + (index * 3)
                : 22 + (index * 4);
            final statusText = (status == 'processing' || status == 'accepted')
                ? 'Delivery partner on route'
                : 'Order placed, dispatch soon';

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #$orderNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Retailer: $shippingName',
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$statusText · ETA $etaMinutes min',
                          style: const TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Our delivery partner is on the route. Tracking is live on map.',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderRouteMapScreen(
                            paymentLat: paymentLat,
                            paymentLng: paymentLng,
                            marketplaceLat: marketLat,
                            marketplaceLng: marketLng,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open Delivery Map'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
