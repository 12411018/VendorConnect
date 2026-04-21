import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:vendorlink/config/map_config.dart';

class MapRouteService {
  const MapRouteService();

  static final Map<String, List<LatLng>> _cache = <String, List<LatLng>>{};

  Future<List<LatLng>> fetchDriveRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final fallback = <LatLng>[LatLng(fromLat, fromLng), LatLng(toLat, toLng)];

    final cacheKey =
        '${fromLat.toStringAsFixed(5)},${fromLng.toStringAsFixed(5)}|${toLat.toStringAsFixed(5)},${toLng.toStringAsFixed(5)}';
    final cached = _cache[cacheKey];
    if (cached != null && cached.length >= 2) {
      return cached;
    }

    try {
      final geoapifyPoints = await _fetchGeoapifyRoute(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );
      if (geoapifyPoints.length >= 2) {
        _cache[cacheKey] = geoapifyPoints;
        return geoapifyPoints;
      }

      final osrmPoints = await _fetchOsrmRoute(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );
      if (osrmPoints.length >= 2) {
        _cache[cacheKey] = osrmPoints;
        return osrmPoints;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[MapRouteService] route fetch failed: $error');
      }
    }

    if (kDebugMode) {
      debugPrint('[MapRouteService] using straight-line fallback route');
    }
    return fallback;
  }

  Future<List<LatLng>> _fetchGeoapifyRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (!MapConfig.hasGeoapifyKey) {
      return const <LatLng>[];
    }

    final uri = Uri.parse(
      'https://api.geoapify.com/v1/routing?waypoints=$fromLng,$fromLat|$toLng,$toLat&mode=drive&apiKey=${MapConfig.geoapifyApiKey}',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint(
          '[MapRouteService][Geoapify] non-200: ${response.statusCode} ${response.body}',
        );
      }
      return const <LatLng>[];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <LatLng>[];
    }

    final features = decoded['features'];
    if (features is! List || features.isEmpty) {
      return const <LatLng>[];
    }

    final feature = features.first;
    if (feature is! Map<String, dynamic>) {
      return const <LatLng>[];
    }

    final geometry = feature['geometry'];
    if (geometry is! Map<String, dynamic>) {
      return const <LatLng>[];
    }

    final points = _extractGeoJsonPoints(geometry);
    if (kDebugMode) {
      debugPrint('[MapRouteService][Geoapify] points=${points.length}');
    }
    return points;
  }

  Future<List<LatLng>> _fetchOsrmRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('[MapRouteService][OSRM] non-200: ${response.statusCode}');
      }
      return const <LatLng>[];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <LatLng>[];
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      return const <LatLng>[];
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map<String, dynamic>) {
      return const <LatLng>[];
    }

    final geometry = firstRoute['geometry'];
    if (geometry is! Map<String, dynamic>) {
      return const <LatLng>[];
    }

    final points = _extractGeoJsonPoints(geometry);
    if (kDebugMode) {
      debugPrint('[MapRouteService][OSRM] points=${points.length}');
    }
    return points;
  }

  List<LatLng> _extractGeoJsonPoints(Map<String, dynamic> geometry) {
    final geometryType = (geometry['type'] ?? '').toString();
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) {
      return const <LatLng>[];
    }

    final points = <LatLng>[];
    if (geometryType == 'LineString') {
      for (final coordinate in coordinates) {
        if (coordinate is List && coordinate.length >= 2) {
          final lng = _toDouble(coordinate[0]);
          final lat = _toDouble(coordinate[1]);
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }
    } else if (geometryType == 'MultiLineString') {
      for (final segment in coordinates) {
        if (segment is! List) {
          continue;
        }
        for (final coordinate in segment) {
          if (coordinate is List && coordinate.length >= 2) {
            final lng = _toDouble(coordinate[0]);
            final lat = _toDouble(coordinate[1]);
            if (lat != null && lng != null) {
              points.add(LatLng(lat, lng));
            }
          }
        }
      }
    }

    return points;
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString());
  }
}
