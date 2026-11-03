import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Simple in-memory zone model (hardcoded for now, can move to Firestore later)
class DriverZone {
  final String id;
  final String name;
  final LatLng center;
  final double zoom;
  final double radiusKm; // conceptual coverage radius
  const DriverZone({
    required this.id,
    required this.name,
    required this.center,
    required this.zoom,
    required this.radiusKm,
  });
}

const kDefaultZones = <DriverZone>[
  DriverZone(
    id: 'dfw_core',
    name: 'DFW Core',
    center: LatLng(32.7791, -97.35),
    zoom: 11.2,
    radiusKm: 30,
  ),
  DriverZone(
    id: 'dfw_north',
    name: 'DFW North',
    center: LatLng(33.0198, -96.6989),
    zoom: 11.2,
    radiusKm: 28,
  ),
  DriverZone(
    id: 'austin',
    name: 'Austin',
    center: LatLng(30.2672, -97.7431),
    zoom: 11.0,
    radiusKm: 26,
  ),
];

/// Store model used for map markers.
class StoreLocation {
  final String id;
  final String brand; // e.g. walmart, gamestop
  final LatLng position;
  final Map<String, dynamic>? hours; // optional hours structure
  StoreLocation({
    required this.id,
    required this.brand,
    required this.position,
    this.hours,
  });
}

/// Service that fetches store documents within a bounding box.
class StoreService {
  final FirebaseFirestore _firestore;
  StoreService(this._firestore);

  Future<List<StoreLocation>> fetchStoresInBounds({
    required LatLngBounds bounds,
    int limit = 150,
  }) async {
    // Firestore doesn't natively query by lat & lng simultaneously without composite setup.
    // Assume documents have fields: geo.lat, geo.lng or field 'location' as GeoPoint.
    // We'll fetch a broader set (limit) and client-filter. In production use geohash indexing.
    final snap = await _firestore.collection('stores').limit(limit).get();
    final List<StoreLocation> results = [];
    for (final doc in snap.docs) {
      final data = doc.data();
      final loc = data['location'];
      if (loc is GeoPoint) {
        final lat = loc.latitude;
        final lng = loc.longitude;
        if (lat >= bounds.southwest.latitude &&
            lat <= bounds.northeast.latitude &&
            lng >= bounds.southwest.longitude &&
            lng <= bounds.northeast.longitude) {
          results.add(
            StoreLocation(
              id: doc.id,
              brand: (data['brand'] as String?) ?? 'store',
              position: LatLng(lat, lng),
              hours: data['hours'] is Map<String, dynamic>
                  ? data['hours'] as Map<String, dynamic>
                  : null,
            ),
          );
        }
      }
    }
    return results;
  }
}
