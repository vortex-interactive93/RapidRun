// File: rapidrun_driver/lib/services/phone_heading_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'driver_camera_helper.dart';

/// Combines the phone's internal magnetic/motion compass heading with
/// movement/road bearing so the chevron points where the phone faces when
/// stationary/slow and tracks driving heading smoothly at speed.
class PhoneHeadingController {
  StreamSubscription<CompassEvent>? _compassSub;
  double? _latestDeviceHeadingDeg;

  double _fusedHeadingDeg = 0.0;
  double get fusedHeadingDeg => _fusedHeadingDeg;

  bool _usePhoneFacingMode = true;
  bool get usePhoneFacingMode => _usePhoneFacingMode;

  void setUsePhoneFacingMode(bool enabled) {
    _usePhoneFacingMode = enabled;
  }

  void startListening({required ValueChanged<double> onHeadingChanged}) {
    _onHeadingChanged = onHeadingChanged;
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen(
      (CompassEvent event) {
        final rawHeading = event.heading;
        if (rawHeading == null || rawHeading.isNaN) return;
        _latestDeviceHeadingDeg = ((rawHeading % 360.0) + 360.0) % 360.0;
        _recomputeAndEmit();
      },
      onError: (Object err) {
        debugPrint('Compass sensor notice: $err');
      },
    );
  }

  ValueChanged<double>? _onHeadingChanged;

  void _recomputeAndEmit() {
    if (_usePhoneFacingMode && _latestDeviceHeadingDeg != null) {
      _fusedHeadingDeg = DriverCameraHelper.lerpAngleDegrees(
        _fusedHeadingDeg,
        _latestDeviceHeadingDeg!,
        0.35,
      );
      _onHeadingChanged?.call(_fusedHeadingDeg);
    }
  }

  /// Updates [fusedHeadingDeg] using device compass heading when slow/stationary,
  /// and road/GPS travel bearing when moving faster than ~5 mph (2.2 m/s).
  double updateHeading({
    required double movementOrRoadBearingDeg,
    required double speedMps,
    double? gpsHeadingDeg,
  }) {
    double targetDeg = movementOrRoadBearingDeg;

    if (_usePhoneFacingMode && _latestDeviceHeadingDeg != null) {
      if (speedMps < 2.2) {
        // Stationary, walking, or virtual joystick test: point where phone faces
        targetDeg = _latestDeviceHeadingDeg!;
      } else {
        // Driving at speed: prioritize travel/road vector, lightly bias compass
        final travelRef = (gpsHeadingDeg != null && gpsHeadingDeg > 0)
            ? DriverCameraHelper.lerpAngleDegrees(
                movementOrRoadBearingDeg,
                gpsHeadingDeg,
                0.4,
              )
            : movementOrRoadBearingDeg;
        targetDeg = DriverCameraHelper.lerpAngleDegrees(
          travelRef,
          _latestDeviceHeadingDeg!,
          0.18,
        );
      }
    } else if (gpsHeadingDeg != null && gpsHeadingDeg > 0 && speedMps >= 1.5) {
      targetDeg = DriverCameraHelper.lerpAngleDegrees(
        movementOrRoadBearingDeg,
        gpsHeadingDeg,
        0.35,
      );
    }

    _fusedHeadingDeg = DriverCameraHelper.lerpAngleDegrees(
      _fusedHeadingDeg,
      targetDeg,
      0.45,
    );
    _onHeadingChanged?.call(_fusedHeadingDeg);
    return _fusedHeadingDeg;
  }

  Future<void> dispose() async {
    await _compassSub?.cancel();
    _compassSub = null;
  }
}
