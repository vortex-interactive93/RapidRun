// File: rapidrun_driver/lib/services/route_polyline_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:rapidrun_shared/rapidrun_shared.dart';

enum DriverRoutingPreference {
  ecoFriendly,
  fastestTraffic,
  avoidHighways,
  fastest,
  noHighways,
}

class DrivingRouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final Duration duration;

  const DrivingRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.duration,
  });

  double get distanceMiles => distanceMeters / 1609.344;
}

/// Computes road-snapped driving routes via Google Routes API (v2) using the
/// driver's selected routing preference (Eco-Gas, Fastest, No Hwy).
class RoutePolylineService {
  RoutePolylineService._();
  static final RoutePolylineService instance = RoutePolylineService._();

  static const String _routesApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_ROUTES_API_KEY',
    defaultValue: 'AIzaSyB1c6_nJBhUsSbLmuGb3HiGfeA29CmOkTQ',
  );

  Future<DrivingRouteResult> computeDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    DriverRoutingPreference preference = DriverRoutingPreference.ecoFriendly,
    String apiKeyOverride = '',
  }) async {
    final effectiveKey =
        apiKeyOverride.trim().isNotEmpty ? apiKeyOverride.trim() : _routesApiKey;

    if (effectiveKey.isNotEmpty) {
      final result = await _fetchGoogleRoutes(
        origin: origin,
        destination: destination,
        preference: preference,
        apiKey: effectiveKey,
      );
      if (result != null && result.points.isNotEmpty) {
        return result;
      }
    }

    // Fallback to OSRM road-snapped polyline so roads are still followed if key isn't passed via --dart-define
    final osrmResult = await _fetchOsrmRoute(origin: origin, destination: destination);
    if (osrmResult != null && osrmResult.points.isNotEmpty) {
      return osrmResult;
    }

    return DrivingRouteResult(
      points: [origin, destination],
      distanceMeters: 0,
      duration: Duration.zero,
    );
  }

  // Backward-compatible helper for callers expecting List<LatLng>
  Future<List<LatLng>> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    DriverRoutingPreference preference = DriverRoutingPreference.ecoFriendly,
  }) async {
    final res = await computeDrivingRoute(
      origin: origin,
      destination: destination,
      preference: preference,
    );
    return res.points;
  }

  Future<DrivingRouteResult?> _fetchGoogleRoutes({
    required LatLng origin,
    required LatLng destination,
    required DriverRoutingPreference preference,
    required String apiKey,
  }) async {
    try {
      final uri = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');

      final bool avoidHighways = preference == DriverRoutingPreference.avoidHighways;
      final String routingPreference = preference == DriverRoutingPreference.fastestTraffic
          ? 'TRAFFIC_AWARE_OPTIMAL'
          : 'TRAFFIC_AWARE';

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
            },
            body: jsonEncode({
              'origin': {
                'location': {
                  'latLng': {
                    'latitude': origin.latitude,
                    'longitude': origin.longitude,
                  },
                },
              },
              'destination': {
                'location': {
                  'latLng': {
                    'latitude': destination.latitude,
                    'longitude': destination.longitude,
                  },
                },
              },
              'travelMode': 'DRIVE',
              'routingPreference': routingPreference,
              'routeModifiers': {
                'avoidTolls': preference == DriverRoutingPreference.ecoFriendly,
                'avoidHighways': avoidHighways,
                'avoidFerries': true,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('Routes API HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) return null;

      final firstRoute = routes.first as Map<String, dynamic>;
      final encoded =
          firstRoute['polyline']?['encodedPolyline']?.toString() ?? '';
      if (encoded.isEmpty) return null;

      final distMeters = (firstRoute['distanceMeters'] as num?)?.toDouble() ?? 0.0;
      final rawDuration = (firstRoute['duration'] ?? '0s').toString();
      final seconds = int.tryParse(rawDuration.replaceAll('s', '')) ?? 0;

      return DrivingRouteResult(
        points: _decodePolyline(encoded),
        distanceMeters: distMeters,
        duration: Duration(seconds: seconds),
      );
    } catch (e) {
      debugPrint('Google Routes API error: $e');
      return null;
    }
  }

  Future<DrivingRouteResult?> _fetchOsrmRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=polyline',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry']?.toString() ?? '';
      if (geometry.isEmpty) return null;

      return DrivingRouteResult(
        points: _decodePolyline(geometry),
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0.0,
        duration: Duration(
          seconds: ((route['duration'] as num?)?.round() ?? 0),
        ),
      );
    } catch (e) {
      debugPrint('OSRM fallback error: $e');
      return null;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
