// File: rapidrun_driver/lib/services/route_navigation_helper.dart

import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_polyline_service.dart';

class SnappedRouteState {
  final LatLng snappedLocation;
  final List<LatLng> remainingPoints;
  final double roadBearing;
  final double distanceToRouteMeters;
  final bool isOffRoute;
  final int activeStepIndex;
  final double distanceToStepMeters;
  final double remainingRouteMeters;

  const SnappedRouteState({
    required this.snappedLocation,
    required this.remainingPoints,
    required this.roadBearing,
    required this.distanceToRouteMeters,
    required this.isOffRoute,
    required this.activeStepIndex,
    required this.distanceToStepMeters,
    required this.remainingRouteMeters,
  });
}

/// Evaluates driver position against the active road polyline:
/// - Snaps driver marker cleanly to road segments
/// - Trims traveled trail behind the driver
/// - Computes true road segment bearing & off-route status
/// - Advances active turn steps smoothly
class RouteNavigationHelper {
  RouteNavigationHelper._();

  static SnappedRouteState evaluate({
    required LatLng rawLocation,
    required List<LatLng> routePoints,
    required List<NavigationStep> steps,
    int currentStepIndex = 0,
    double fallbackHeading = 0.0,
    double maxSnapMeters = 55.0,
    double offRouteThresholdMeters = 68.0,
    double stepAdvanceThresholdMeters = 32.0,
  }) {
    if (routePoints.isEmpty) {
      return SnappedRouteState(
        snappedLocation: rawLocation,
        remainingPoints: const [],
        roadBearing: fallbackHeading,
        distanceToRouteMeters: 0,
        isOffRoute: false,
        activeStepIndex: 0,
        distanceToStepMeters: 0,
        remainingRouteMeters: 0,
      );
    }

    if (routePoints.length == 1) {
      return SnappedRouteState(
        snappedLocation: routePoints.first,
        remainingPoints: routePoints,
        roadBearing: fallbackHeading,
        distanceToRouteMeters: 0,
        isOffRoute: false,
        activeStepIndex: 0,
        distanceToStepMeters: 0,
        remainingRouteMeters: 0,
      );
    }

    // 1. Closest point on polyline segments
    LatLng bestPoint = rawLocation;
    double bestDistMeters = double.infinity;
    int closestVertexIdx = 0;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final a = routePoints[i];
      final b = routePoints[i + 1];
      final projected = _projectOntoSegment(rawLocation, a, b);
      final d = Geolocator.distanceBetween(
        rawLocation.latitude,
        rawLocation.longitude,
        projected.latitude,
        projected.longitude,
      );
      if (d < bestDistMeters) {
        bestDistMeters = d;
        bestPoint = projected;
        closestVertexIdx = i;
      }
    }

    final bool offRoute = bestDistMeters > offRouteThresholdMeters;
    final snappedLoc = bestDistMeters <= maxSnapMeters ? bestPoint : rawLocation;

    // 2. Remaining route points ahead of snapped position (erases traveled trail)
    final remaining = <LatLng>[snappedLoc];
    for (int i = closestVertexIdx + 1; i < routePoints.length; i++) {
      remaining.add(routePoints[i]);
    }

    // 3. Road segment bearing
    final segStart = routePoints[closestVertexIdx];
    final segEnd =
        routePoints[(closestVertexIdx + 1).clamp(0, routePoints.length - 1)];
    final double bearing = (segStart.latitude == segEnd.latitude &&
            segStart.longitude == segEnd.longitude)
        ? fallbackHeading
        : _computeBearing(segStart, segEnd);

    // 4. Advance step when approaching/passing current maneuver target
    int stepIdx =
        steps.isEmpty ? 0 : currentStepIndex.clamp(0, steps.length - 1);

    if (steps.isNotEmpty) {
      while (stepIdx < steps.length - 1) {
        final distToEnd = Geolocator.distanceBetween(
          snappedLoc.latitude,
          snappedLoc.longitude,
          steps[stepIdx].endLocation.latitude,
          steps[stepIdx].endLocation.longitude,
        );
        if (distToEnd <= stepAdvanceThresholdMeters) {
          stepIdx++;
        } else {
          break;
        }
      }
    }

    final double distToStep = steps.isNotEmpty
        ? Geolocator.distanceBetween(
            snappedLoc.latitude,
            snappedLoc.longitude,
            steps[stepIdx].endLocation.latitude,
            steps[stepIdx].endLocation.longitude,
          )
        : 0.0;

    // 5. Remaining distance along the road ahead
    double remainingMeters = 0.0;
    for (int i = 0; i < remaining.length - 1; i++) {
      remainingMeters += Geolocator.distanceBetween(
        remaining[i].latitude,
        remaining[i].longitude,
        remaining[i + 1].latitude,
        remaining[i + 1].longitude,
      );
    }

    return SnappedRouteState(
      snappedLocation: snappedLoc,
      remainingPoints: remaining,
      roadBearing: bearing,
      distanceToRouteMeters: bestDistMeters,
      isOffRoute: offRoute,
      activeStepIndex: stepIdx,
      distanceToStepMeters: distToStep,
      remainingRouteMeters: remainingMeters,
    );
  }

  static double _computeBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    return (brng + 360.0) % 360.0;
  }

  static LatLng _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    const metersPerDegLat = 111320.0;
    final cosLat = math.cos(p.latitude * math.pi / 180.0);
    final metersPerDegLng = 111320.0 * (cosLat.abs() < 0.01 ? 0.01 : cosLat);

    final ax = (a.longitude - p.longitude) * metersPerDegLng;
    final ay = (a.latitude - p.latitude) * metersPerDegLat;
    final bx = (b.longitude - p.longitude) * metersPerDegLng;
    final by = (b.latitude - p.latitude) * metersPerDegLat;

    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    if (lenSq <= 0.0001) return a;

    final t = ((-ax * dx - ay * dy) / lenSq).clamp(0.0, 1.0);
    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }
}
