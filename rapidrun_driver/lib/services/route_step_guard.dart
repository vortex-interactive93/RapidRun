// File: rapidrun_driver/lib/services/route_step_guard.dart

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_polyline_service.dart';

/// Prevents the turn-by-turn banner from stepping backward or showing
/// increasing turn distances after the driver has already passed a maneuver point.
class RouteStepGuard {
  int _committedStepIndex = 0;

  int get committedStepIndex => _committedStepIndex;

  void reset() {
    _committedStepIndex = 0;
  }

  int resolveForwardStepIndex({
    required LatLng driverLocation,
    required List<NavigationStep> steps,
    int candidateStepIndex = 0,
    double passThresholdMeters = 35.0,
  }) {
    if (steps.isEmpty) return 0;

    int idx = candidateStepIndex < _committedStepIndex
        ? _committedStepIndex
        : candidateStepIndex;
    idx = idx.clamp(0, steps.length - 1);

    // Advance monotonically if driver is within passThresholdMeters of step endLocation
    while (idx < steps.length - 1) {
      final distToEnd = Geolocator.distanceBetween(
        driverLocation.latitude,
        driverLocation.longitude,
        steps[idx].endLocation.latitude,
        steps[idx].endLocation.longitude,
      );
      if (distToEnd <= passThresholdMeters) {
        idx++;
      } else {
        break;
      }
    }

    _committedStepIndex = idx;
    return _committedStepIndex;
  }
}
