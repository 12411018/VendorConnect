import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vendorlink/config/map_config.dart';
import 'package:vendorlink/services/auth/auth_service.dart';
import 'package:vendorlink/services/map_route_service.dart';

class RetailerDeliveryPage extends StatelessWidget {
  const RetailerDeliveryPage({super.key});

  static const double _katrajLat = MapConfig.marketplaceLat;
  static const double _katrajLng = MapConfig.marketplaceLng;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: authService.watchRetailerOrders(),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <Map<String, dynamic>>[];
        final latestOrder = orders.isEmpty ? null : orders.first;
        final status = _effectiveStatus(latestOrder);

        final paymentLat =
            _toDoubleOrNull(latestOrder?['payment_lat']) ??
            _toDoubleOrNull(latestOrder?['marketplace_lat']) ??
            _katrajLat;
        final paymentLng =
            _toDoubleOrNull(latestOrder?['payment_lng']) ??
            _toDoubleOrNull(latestOrder?['marketplace_lng']) ??
            _katrajLng;
        final marketplaceLat =
            _toDoubleOrNull(latestOrder?['marketplace_lat']) ?? _katrajLat;
        final marketplaceLng =
            _toDoubleOrNull(latestOrder?['marketplace_lng']) ?? _katrajLng;

        final paymentPoint = LatLng(paymentLat, paymentLng);
        final marketplacePoint = LatLng(marketplaceLat, marketplaceLng);
        final isSamePoint =
            (paymentLat - marketplaceLat).abs() < 0.0002 &&
            (paymentLng - marketplaceLng).abs() < 0.0002;
        final center = LatLng(
          (paymentLat + marketplaceLat) / 2,
          (paymentLng + marketplaceLng) / 2,
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orders.isEmpty) {
          return const Center(
            child: Text('No deliveries yet. Place an order to start tracking.'),
          );
        }

        final etaText = switch (status) {
          'processing' => 'Arriving in 12-18 min',
          'accepted' => 'Arriving in 12-18 min',
          'delivered' => 'Delivered successfully',
          _ => 'Dispatching soon (20-30 min)',
        };
        final statusText = switch (status) {
          'processing' => 'Our delivery partner is on the route to your shop.',
          'accepted' => 'Our delivery partner is on the route to your shop.',
          'delivered' =>
            'Order delivered. Thank you for shopping with VendorConnect.',
          _ => 'Order placed. Wholesaler will dispatch your delivery shortly.',
        };
        final isDelivered = status == 'delivered';

        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etaText,
                    style: const TextStyle(
                      color: Color(0xFFBAE6FD),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: isDelivered
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF14532D)),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF22C55E),
                                  size: 44,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Delivery completed',
                                  style: TextStyle(
                                    color: Color(0xFFF8FAFC),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'No Orders Yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: !MapConfig.hasGeoapifyKey
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Map API key missing. Set key in map config or use --dart-define=GEOAPIFY_API_KEY=YOUR_KEY',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : FutureBuilder<List<LatLng>>(
                                future: const MapRouteService().fetchDriveRoute(
                                  fromLat: paymentLat,
                                  fromLng: paymentLng,
                                  toLat: marketplaceLat,
                                  toLng: marketplaceLng,
                                ),
                                builder: (context, routeSnapshot) {
                                  final routePoints =
                                      routeSnapshot.data ??
                                      <LatLng>[paymentPoint, marketplacePoint];
                                  final routeBounds = LatLngBounds.fromPoints(
                                    routePoints,
                                  );

                                  if (routeSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  return FlutterMap(
                                    options: MapOptions(
                                      initialCenter: center,
                                      initialZoom: isSamePoint ? 16 : 13,
                                      initialCameraFit: isSamePoint
                                          ? null
                                          : CameraFit.bounds(
                                              bounds: routeBounds,
                                              padding: const EdgeInsets.all(52),
                                              maxZoom: 17,
                                              minZoom: 11,
                                            ),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.vendorlink.app',
                                      ),
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: routePoints,
                                            color: const Color(0xFF22C55E),
                                            strokeWidth: 5,
                                          ),
                                        ],
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: paymentPoint,
                                            width: 130,
                                            height: 40,
                                            child: _mapChip(
                                              label: 'Your location',
                                              color: const Color(0xFF16A34A),
                                            ),
                                          ),
                                          Marker(
                                            point: marketplacePoint,
                                            width: 180,
                                            height: 40,
                                            child: _mapChip(
                                              label: MapConfig.marketplaceName,
                                              color: const Color(0xFF2563EB),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
              ),
            ),
            if (!isDelivered)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Text(
                  'Live tracking active. Keep this page open for route and ETA updates.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
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

  String _effectiveStatus(Map<String, dynamic>? order) {
    if (order == null) {
      return 'pending';
    }

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

  Widget _mapChip({required String label, required Color color}) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
