// File: rapidrun_driver/lib/services/driver_telemetry_service.dart

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverTelemetryService {
  static StreamSubscription<Position>? _positionSub;

  static void startBroadcasting({required String orderId}) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Send update every 5 meters
    );

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'driverLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'speed': position.speed,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    });
  }

  static void stopBroadcasting() {
    _positionSub?.cancel();
    _positionSub = null;
  }
}
