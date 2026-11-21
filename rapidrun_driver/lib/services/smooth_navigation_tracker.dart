// File: rapidrun_driver/lib/services/smooth_navigation_tracker.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'driver_camera_helper.dart';
import 'route_navigation_helper.dart';
import 'route_polyline_service.dart';

/// Delivers 60fps vehicle puck interpolation + 500ms high-frequency GPS polling
/// along the active road polyline so the puck glides smoothly without 5-10s jumps.
class SmoothNavigationTracker {
  StreamSubscription<Position>? _gpsSub;
  Ticker? _frameTicker;

  LatLng _interpStartLoc = const LatLng(32.7568, -97.4768);
  LatLng _interpTargetLoc = const LatLng(32.7568, -97.4768);
  LatLng _renderedLoc = const LatLng(32.7568, -97.4768);

  double _interpStartHeading = 0.0;
  double _interpTargetHeading = 0.0;
  double _renderedHeading = 0.0;

  double _currentSpeedMps = 0.0;
  DateTime _lastGpsFixAt = DateTime.now();
  Duration _interpDuration = const Duration(milliseconds: 550);

  LatLng get renderedLocation => _renderedLoc;
  double get renderedHeading => _renderedHeading;
  double get currentSpeedMps => _currentSpeedMps;

  static LocationSettings buildHighFreqLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
        forceLocationManager: false,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  void start({
    required TickerProvider vsync,
    required LatLng initialLocation,
    required double initialHeading,
    required List<LatLng> Function() getFullRoutePoints,
    required List<NavigationStep> Function() getSteps,
    required int Function() getActiveStepIndex,
    required void Function(Position rawPos, SnappedRouteState snapped) onGpsFix,
    required void Function(LatLng smoothLoc, double smoothHeading) onFrameTick,
  }) {
    _interpStartLoc = initialLocation;
    _interpTargetLoc = initialLocation;
    _renderedLoc = initialLocation;
    _interpStartHeading = initialHeading;
    _interpTargetHeading = initialHeading;
    _renderedHeading = initialHeading;
    _lastGpsFixAt = DateTime.now();

    _frameTicker?.dispose();
    _frameTicker = vsync.createTicker((_) {
      final elapsedMs =
          DateTime.now().difference(_lastGpsFixAt).inMilliseconds;
      final totalMs = _interpDuration.inMilliseconds.clamp(250, 1200);
      final rawT = (elapsedMs / totalMs).clamp(0.0, 1.0);
      // Ease-out curve so marker position glides smoothly into each GPS fix
      final t = 1.0 - (1.0 - rawT) * (1.0 - rawT);

      final lat = _interpStartLoc.latitude +
          (_interpTargetLoc.latitude - _interpStartLoc.latitude) * t;
      final lng = _interpStartLoc.longitude +
          (_interpTargetLoc.longitude - _interpStartLoc.longitude) * t;

      _renderedLoc = LatLng(lat, lng);
      _renderedHeading = DriverCameraHelper.lerpAngleDegrees(
        _interpStartHeading,
        _interpTargetHeading,
        t,
      );

      onFrameTick(_renderedLoc, _renderedHeading);
    });
    _frameTicker!.start();

    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: buildHighFreqLocationSettings(),
    ).listen((Position pos) {
      final now = DateTime.now();
      final dtMs = now.difference(_lastGpsFixAt).inMilliseconds.clamp(300, 1100);
      _interpDuration = Duration(milliseconds: dtMs);
      _lastGpsFixAt = now;

      final rawLatLng = LatLng(pos.latitude, pos.longitude);
      final routePts = getFullRoutePoints();

      final snappedState = RouteNavigationHelper.evaluate(
        rawLocation: rawLatLng,
        routePoints: routePts,
        steps: getSteps(),
        currentStepIndex: getActiveStepIndex(),
        fallbackHeading: _renderedHeading,
        maxSnapMeters: 80.0,
        offRouteThresholdMeters: 110.0,
      );

      _currentSpeedMps = pos.speed.clamp(0.0, 60.0);

      _interpStartLoc = _renderedLoc;
      _interpTargetLoc = rawLatLng;

      _interpStartHeading = _renderedHeading;
      final double targetBrg = (pos.heading > 0 && _currentSpeedMps > 1.5)
          ? DriverCameraHelper.lerpAngleDegrees(
              snappedState.roadBearing,
              pos.heading,
              0.30,
            )
          : snappedState.roadBearing;
      _interpTargetHeading = targetBrg;

      onGpsFix(pos, snappedState);
    });
  }

  void dispose() {
    _frameTicker?.stop();
    _frameTicker?.dispose();
    _frameTicker = null;
    _gpsSub?.cancel();
    _gpsSub = null;
  }
}
