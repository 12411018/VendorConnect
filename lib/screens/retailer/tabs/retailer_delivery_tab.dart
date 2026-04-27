import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vendorlink/services/map_route_service.dart';

class RetailerDeliveryTab extends StatefulWidget {
  const RetailerDeliveryTab({super.key});

  @override
  State<RetailerDeliveryTab> createState() => _RetailerDeliveryTabState();
}

class _RetailerDeliveryTabState extends State<RetailerDeliveryTab> {
  final MapRouteService _routeService = const MapRouteService();
  List<LatLng> _routePoints = [];
  bool _isLoading = true;

  // Mock coordinates for demonstration based on the image (Katraj area)
  final LatLng _wholesalerLocation = const LatLng(18.4575, 73.8508); // PICT College
  final LatLng _retailerLocation = const LatLng(18.4485, 73.8650); // Near Katraj Snake Park

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    try {
      final points = await _routeService.fetchDriveRoute(
        fromLat: _wholesalerLocation.latitude,
        fromLng: _wholesalerLocation.longitude,
        toLat: _retailerLocation.latitude,
        toLng: _retailerLocation.longitude,
      );
      if (mounted) {
        setState(() {
          _routePoints = points;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using a dark theme style similar to the image
    final backgroundColor = const Color(0xFF0F172A);
    final cardColor = const Color(0xFF1E293B);
    final primaryBlue = const Color(0xFF3B82F6);
    final accentGreen = const Color(0xFF10B981);

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Top Status Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispatching soon (20-30 min)',
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Order placed. Wholesaler will dispatch your delivery shortly.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Map Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            (_wholesalerLocation.latitude + _retailerLocation.latitude) / 2,
                            (_wholesalerLocation.longitude + _retailerLocation.longitude) / 2,
                          ),
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.vendorlink',
                          ),
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: accentGreen,
                                  strokeWidth: 5.0,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _wholesalerLocation,
                                width: 140,
                                height: 40,
                                child: _buildLocationLabel('PICT College, Katraj', primaryBlue),
                              ),
                              Marker(
                                point: _retailerLocation,
                                width: 120,
                                height: 40,
                                child: _buildLocationLabel('Your location', accentGreen),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Bottom Info Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Live tracking active. Keep this page open for route and ETA updates.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationLabel(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
