import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vendorlink/config/map_config.dart';
import 'package:vendorlink/services/map_route_service.dart';

class OrderRouteMapScreen extends StatefulWidget {
  const OrderRouteMapScreen({
    super.key,
    required this.paymentLat,
    required this.paymentLng,
    required this.marketplaceLat,
    required this.marketplaceLng,
  });

  final double paymentLat;
  final double paymentLng;
  final double marketplaceLat;
  final double marketplaceLng;

  @override
  State<OrderRouteMapScreen> createState() => _OrderRouteMapScreenState();
}

class _OrderRouteMapScreenState extends State<OrderRouteMapScreen> {
  late final Future<List<LatLng>> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = const MapRouteService().fetchDriveRoute(
      fromLat: widget.paymentLat,
      fromLng: widget.paymentLng,
      toLat: widget.marketplaceLat,
      toLng: widget.marketplaceLng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentPoint = LatLng(widget.paymentLat, widget.paymentLng);
    final marketplacePoint = LatLng(
      widget.marketplaceLat,
      widget.marketplaceLng,
    );
    final isSamePoint =
        (widget.paymentLat - widget.marketplaceLat).abs() < 0.0002 &&
        (widget.paymentLng - widget.marketplaceLng).abs() < 0.0002;
    final center = LatLng(
      (widget.paymentLat + widget.marketplaceLat) / 2,
      (widget.paymentLng + widget.marketplaceLng) / 2,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Order Route Map')),
      body: !MapConfig.hasGeoapifyKey
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Geoapify API key missing. Run with --dart-define=GEOAPIFY_API_KEY=YOUR_KEY',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FutureBuilder<List<LatLng>>(
              future: _routeFuture,
              builder: (context, snapshot) {
                final routePoints =
                    snapshot.data ?? <LatLng>[paymentPoint, marketplacePoint];
                final routeBounds = LatLngBounds.fromPoints(routePoints);

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: isSamePoint ? 16 : 13,
                    initialCameraFit: isSamePoint
                        ? null
                        : CameraFit.bounds(
                            bounds: routeBounds,
                            padding: const EdgeInsets.all(56),
                            maxZoom: 17,
                            minZoom: 11,
                          ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vendorlink.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 5,
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: paymentPoint,
                          width: 130,
                          height: 42,
                          child: _mapLabel('Payment location', Colors.green),
                        ),
                        Marker(
                          point: marketplacePoint,
                          width: 160,
                          height: 42,
                          child: _mapLabel(
                            MapConfig.marketplaceName,
                            Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _mapLabel(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
