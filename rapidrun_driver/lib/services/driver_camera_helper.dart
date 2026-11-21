// File: rapidrun_driver/lib/services/driver_camera_helper.dart

import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriverCameraHelper {
  DriverCameraHelper._();

  static const double _earthRadiusMeters = 6378137.0;

  /// Computes compass bearing (0..360 deg, 0=North, 90=East) from [from] to [to].
  static double bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final deg = math.atan2(y, x) * 180.0 / math.pi;
    return (deg + 360.0) % 360.0;
  }

  /// Shortest-path angular interpolation across the 0/360 degree wrap boundary.
  static double lerpAngleDegrees(double currentDeg, double targetDeg, double t) {
    final a = (currentDeg % 360.0 + 360.0) % 360.0;
    final b = (targetDeg % 360.0 + 360.0) % 360.0;
    final diff = (b - a + 540.0) % 360.0 - 180.0;
    return (a + diff * t.clamp(0.0, 1.0) + 360.0) % 360.0;
  }

  /// Converts a 0..360 degree heading into a crisp cardinal label (N, NE, E, SE...).
  static String cardinalDirection(double headingDeg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalized = ((headingDeg % 360.0) + 360.0) % 360.0;
    final idx = ((normalized + 22.5) / 45.0).floor() % 8;
    return dirs[idx];
  }

  static LatLng offsetCoordinate({
    required LatLng origin,
    required double distanceMeters,
    required double bearingDegrees,
  }) {
    final bearingRad = bearingDegrees * math.pi / 180.0;
    final lat1 = origin.latitude * math.pi / 180.0;
    final lon1 = origin.longitude * math.pi / 180.0;
    final angularDistance = distanceMeters / _earthRadiusMeters;

    final sinLat1 = math.sin(lat1);
    final cosLat1 = math.cos(lat1);
    final sinAd = math.sin(angularDistance);
    final cosAd = math.cos(angularDistance);

    final lat2 = math.asin(
      sinLat1 * cosAd + cosLat1 * sinAd * math.cos(bearingRad),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(bearingRad) * sinAd * cosLat1,
          cosAd - sinLat1 * math.sin(lat2),
        );

    return LatLng(lat2 * 180.0 / math.pi, lon2 * 180.0 / math.pi);
  }

  /// Builds either a 3D forward-looking cockpit camera or a crisp North-Up camera.
  static CameraPosition buildNavigationCamera({
    required LatLng driverLocation,
    required double headingDegrees,
    required bool northUpMode,
    double zoom3D = 18.4,
    double tilt3D = 63.0,
    double lookAheadMeters = 120.0,
  }) {
    if (northUpMode) {
      return CameraPosition(
        target: driverLocation,
        bearing: 0.0,
        tilt: 0.0,
        zoom: 17.2,
      );
    }

    final lookAheadTarget = offsetCoordinate(
      origin: driverLocation,
      distanceMeters: lookAheadMeters,
      bearingDegrees: headingDegrees,
    );

    return CameraPosition(
      target: lookAheadTarget,
      bearing: headingDegrees,
      tilt: tilt3D,
      zoom: zoom3D,
    );
  }
}
