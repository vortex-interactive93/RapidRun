// File: lib/widgets/tracking/animated_driver_map.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnimatedDriverMap extends StatefulWidget {
  final String orderId;
  final LatLng destinationCoords;

  const AnimatedDriverMap({
    super.key,
    required this.orderId,
    required this.destinationCoords,
  });

  @override
  State<AnimatedDriverMap> createState() => _AnimatedDriverMapState();
}

class _AnimatedDriverMapState extends State<AnimatedDriverMap>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _animController;

  LatLng _prevPosition = const LatLng(32.7561, -97.4619); // Default Westover
  LatLng _currentPosition = const LatLng(32.7561, -97.4619);
  double _prevBearing = 0.0;
  double _currentBearing = 0.0;

  BitmapDescriptor? _destinationIcon;

  static const String _darkMapJson = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#121418"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#747880"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#121418"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1E222A"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2A2F3A"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#090A0D"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _loadCustomMarkers();
    _subscribeToDriverTelemetry();
  }

  @override
  void dispose() {
    _animController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarkers() async {
    _destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    if (mounted) setState(() {});
  }

  void _subscribeToDriverTelemetry() {
    FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data();
      final driverLocation = data?['driverLocation'] as Map<String, dynamic>?;

      if (driverLocation != null) {
        final double newLat = (driverLocation['latitude'] as num).toDouble();
        final double newLng = (driverLocation['longitude'] as num).toDouble();
        final LatLng target = LatLng(newLat, newLng);

        final double calculatedBearing = _calculateBearing(_currentPosition, target);

        setState(() {
          _prevPosition = _currentPosition;
          _currentPosition = target;
          _prevBearing = _currentBearing;
          _currentBearing = calculatedBearing;
        });

        _animController.forward(from: 0.0);

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(target),
        );
      }
    });
  }

  /// Calculates geodesic rotation bearing for car heading orientation
  double _calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * (math.pi / 180.0);
    final double lon1 = start.longitude * (math.pi / 180.0);
    final double lat2 = end.latitude * (math.pi / 180.0);
    final double lon2 = end.longitude * (math.pi / 180.0);

    final double dLon = lon2 - lon1;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double radians = math.atan2(y, x);
    return ((radians * 180.0 / math.pi) + 360.0) % 360.0;
  }

  LatLng _interpolatePosition(double t) {
    final double lat = _prevPosition.latitude +
        (_currentPosition.latitude - _prevPosition.latitude) * t;
    final double lng = _prevPosition.longitude +
        (_currentPosition.longitude - _prevPosition.longitude) * t;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final LatLng interpolatedPos = _interpolatePosition(_animController.value);
        final double interpolatedBearing = _prevBearing +
            (_currentBearing - _prevBearing) * _animController.value;

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentPosition,
            zoom: 15.5,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            controller.setMapStyle(_darkMapJson);
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          markers: {
            // Animated Delivery Vehicle Marker
            Marker(
              markerId: const MarkerId('driver_puck'),
              position: interpolatedPos,
              rotation: interpolatedBearing,
              anchor: const Offset(0.5, 0.5),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              flat: true,
            ),
            // Destination Home Marker
            Marker(
              markerId: const MarkerId('customer_home'),
              position: widget.destinationCoords,
              icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
            ),
          },
        );
      },
    );
  }
}
