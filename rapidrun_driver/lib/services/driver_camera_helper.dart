// File: rapidrun_driver/lib/services/driver_camera_helper.dart

import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Computes a 3D first-person driving CameraPosition matching Google Maps navigation:
/// - Places driver vehicle puck at bottom ~15% of screen
/// - Rotates camera bearing to driver travel direction
/// - Tilts 3D perspective to 62° for deep street visibility ahead
class DriverCameraHelper {
  DriverCameraHelper._();

  static const double _earthRadiusMeters = 6378137.0;

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

  /// Builds a 3D first-person driving camera position anchored at bottom 15% of screen
  static CameraPosition buildForward3DCamera({
    required LatLng driverLocation,
    required double bearingDegrees,
    double zoom = 18.2,
    double tilt = 62.0,
    double lookAheadMeters = 95.0,
  }) {
    final lookAheadTarget = offsetCoordinate(
      origin: driverLocation,
      distanceMeters: lookAheadMeters,
      bearingDegrees: bearingDegrees,
    );

    return CameraPosition(
      target: lookAheadTarget,
      bearing: bearingDegrees,
      tilt: tilt,
      zoom: zoom,
    );
  }
}
