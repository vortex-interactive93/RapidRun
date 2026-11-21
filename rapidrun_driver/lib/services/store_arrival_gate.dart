// File: rapidrun_driver/lib/services/store_arrival_gate.dart

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class StoreArrivalStatus {
  final double distanceMeters;
  final bool isWithinRadius;
  final String distanceLabel;

  const StoreArrivalStatus({
    required this.distanceMeters,
    required this.isWithinRadius,
    required this.distanceLabel,
  });
}

/// Enforces proximity to the pickup store before allowing store arrival & picking,
/// firing a single haptic pulse when the driver enters the arrival geofence.
class StoreArrivalGate {
  bool _hasPulsedOnEntry = false;

  void reset() {
    _hasPulsedOnEntry = false;
  }

  StoreArrivalStatus evaluate({
    required LatLng currentLocation,
    required LatLng storeLocation,
    double radiusMeters = 75.0,
  }) {
    final meters = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      storeLocation.latitude,
      storeLocation.longitude,
    );

    final within = meters <= radiusMeters;
    if (within && !_hasPulsedOnEntry) {
      _hasPulsedOnEntry = true;
      HapticFeedback.heavyImpact();
    } else if (!within) {
      _hasPulsedOnEntry = false;
    }

    final feet = meters * 3.28084;
    final label = meters < 400
        ? '${feet.round()} ft away'
        : '${(meters / 1609.344).toStringAsFixed(1)} mi away';

    return StoreArrivalStatus(
      distanceMeters: meters,
      isWithinRadius: within,
      distanceLabel: label,
    );
  }
}
