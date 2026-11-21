// File: rapidrun_driver/lib/services/route_navigation_helper.dart

import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_polyline_service.dart';

class SnappedRouteState {
  final LatLng snappedLocation;
  final int activeStepIndex;
  final double distanceToStepMeters;
  final double remainingRouteMeters;

  const SnappedRouteState({
    required this.snappedLocation,
    required this.activeStepIndex,
    required this.distanceToStepMeters,
    required this.remainingRouteMeters,
  });
}

/// Snaps simulated or noisy GPS coordinates onto the road-snapped polyline and
/// advances the active turn step as the driver approaches each maneuver point.
class RouteNavigationHelper {
  RouteNavigationHelper._();

  static SnappedRouteState evaluate({
    required LatLng rawLocation,
    required List<LatLng> routePoints,
    required List<NavigationStep> steps,
    int currentStepIndex = 0,
    double maxSnapMeters = 45.0,
    double stepAdvanceThresholdMeters = 28.0,
  }) {
    if (routePoints.isEmpty) {
      return SnappedRouteState(
        snappedLocation: rawLocation,
        activeStepIndex: 0,
        distanceToStepMeters: 0,
        remainingRouteMeters: 0,
      );
    }

    // 1. Find closest point on polyline segments so joystick drift stays road-aligned
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

    final snappedLoc =
        bestDistMeters <= maxSnapMeters ? bestPoint : rawLocation;

    // 2. Advance active step if within threshold of current step's endLocation
    int stepIdx = steps.isEmpty
        ? 0
        : currentStepIndex.clamp(0, steps.length - 1);

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

    // 3. Sum remaining polyline distance from snapped point to route end
    double remainingMeters = Geolocator.distanceBetween(
      snappedLoc.latitude,
      snappedLoc.longitude,
      routePoints[(closestVertexIdx + 1).clamp(0, routePoints.length - 1)]
          .latitude,
      routePoints[(closestVertexIdx + 1).clamp(0, routePoints.length - 1)]
          .longitude,
    );

    for (int i = closestVertexIdx + 1; i < routePoints.length - 1; i++) {
      remainingMeters += Geolocator.distanceBetween(
        routePoints[i].latitude,
        routePoints[i].longitude,
        routePoints[i + 1].latitude,
        routePoints[i + 1].longitude,
      );
    }

    return SnappedRouteState(
      snappedLocation: snappedLoc,
      activeStepIndex: stepIdx,
      distanceToStepMeters: distToStep,
      remainingRouteMeters: remainingMeters,
    );
  }

  static LatLng _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    // Equirectangular local projection for fast, accurate sub-100m geometry
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
    final projLng = a.longitude + t * (b.longitude - a.longitude);
    final projLat = a.latitude + t * (b.latitude - a.latitude);
    return LatLng(projLat, projLng);
  }
}
