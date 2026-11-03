// File: packages/rapidrun_shared/lib/src/services/free_routing_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FreeRoutingService {
  /// Fetches street-level driving route coordinates with zero API keys or billing holds
  static Future<List<LatLng>> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'RapidRun-App/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final coordinates = routes[0]['geometry']['coordinates'] as List<dynamic>;
          return coordinates.map((coord) {
            // GeoJSON returns [lon, lat]
            final double lng = (coord[0] as num).toDouble();
            final double lat = (coord[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();
        }
      }
    } catch (e) {
      // Fallback: Straight-line point-to-point if network is offline
      return [origin, destination];
    }

    return [origin, destination];
  }
}
