// File: rapidrun_driver/lib/services/arrival_proximity_helper.dart

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Detects when a driver enters arrival range of a store or customer drop-off
/// and fires a single haptic confirmation pulse when threshold is first crossed.
class ArrivalProximityHelper {
  bool _hasAlertedArrival = false;
  bool get hasAlertedArrival => _hasAlertedArrival;

  void reset() {
    _hasAlertedArrival = false;
  }

  bool checkWithinRange({
    required LatLng currentLocation,
    required LatLng targetLocation,
    double thresholdMeters = 50.0,
  }) {
    final distanceMeters = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      targetLocation.latitude,
      targetLocation.longitude,
    );

    final withinRange = distanceMeters <= thresholdMeters;
    if (withinRange && !_hasAlertedArrival) {
      _hasAlertedArrival = true;
      HapticFeedback.heavyImpact();
    }
    return withinRange;
  }
}
