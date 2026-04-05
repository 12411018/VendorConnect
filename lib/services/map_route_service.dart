import 'dart:convert';

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
    if (!MapConfig.hasGeoapifyKey) {
      return fallback;
    }

    final cacheKey =
        '${fromLat.toStringAsFixed(5)},${fromLng.toStringAsFixed(5)}|${toLat.toStringAsFixed(5)},${toLng.toStringAsFixed(5)}';
    final cached = _cache[cacheKey];
    if (cached != null && cached.length >= 2) {
      return cached;
    }

    try {
      final uri = Uri.parse(
        'https://api.geoapify.com/v1/routing?waypoints=$fromLat,$fromLng|$toLat,$toLng&mode=drive&apiKey=${MapConfig.geoapifyApiKey}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return fallback;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }

      final features = decoded['features'];
      if (features is! List || features.isEmpty) {
        return fallback;
      }

      final feature = features.first;
      if (feature is! Map<String, dynamic>) {
        return fallback;
      }

      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) {
        return fallback;
      }

      final geometryType = (geometry['type'] ?? '').toString();
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) {
        return fallback;
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
      } else {
        return fallback;
      }

      if (points.length < 2) {
        return fallback;
      }

      _cache[cacheKey] = points;
      return points;
    } catch (_) {
      return fallback;
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString());
  }
}
