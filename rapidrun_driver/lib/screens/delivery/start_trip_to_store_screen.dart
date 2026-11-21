// File: rapidrun_driver/lib/screens/delivery/start_trip_to_store_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../presentation/home/map_styles/midnight_titanium.dart';
import '../../services/route_polyline_service.dart';
import '../shopping/in_store_picking_screen.dart';

class StartTripToStoreScreen extends StatefulWidget {
  final String orderId;
  final String storeName;
  final String storeAddress;
  final double storeLat;
  final double storeLng;
  final DriverRoutingPreference routingPreference;
  final List<PickItem> items;

  const StartTripToStoreScreen({
    super.key,
    required this.orderId,
    required this.storeName,
    this.storeAddress = 'Westover Village, Fort Worth, TX',
    this.storeLat = 32.7482,
    this.storeLng = -97.4248,
    this.routingPreference = DriverRoutingPreference.ecoFriendly,
    required this.items,
  });

  @override
  State<StartTripToStoreScreen> createState() => _StartTripToStoreScreenState();
}

class _StartTripToStoreScreenState extends State<StartTripToStoreScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _posSub;

  LatLng _currentLoc = const LatLng(32.7568, -97.4768);
  late final LatLng _storeLoc;
  List<LatLng> _routePoints = const [];
  bool _tripStarted = false;
  bool _mapReady = false;
  double _distanceMiles = 0.0;
  int _etaMinutes = 0;

  @override
  void initState() {
    super.initState();
    _storeLoc = LatLng(widget.storeLat, widget.storeLng);
    _initLocationAndRoute();
  }

  Future<void> _initLocationAndRoute() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _currentLoc = LatLng(pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint('Initial store GPS notice: $e');
    }

    await _recalculateRoute();

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) async {
      if (!mounted) return;
      final updated = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLoc = updated);

      FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({
        'driverLat': pos.latitude,
        'driverLng': pos.longitude,
        'driverHeading': pos.heading,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});

      await _recalculateRoute();
    });
  }

  Future<void> _recalculateRoute() async {
    final result = await RoutePolylineService.instance.computeDrivingRoute(
      origin: _currentLoc,
      destination: _storeLoc,
      preference: widget.routingPreference,
    );

    final fallbackMeters = Geolocator.distanceBetween(
      _currentLoc.latitude,
      _currentLoc.longitude,
      _storeLoc.latitude,
      _storeLoc.longitude,
    );
    final miles = result.distanceMeters > 0
        ? result.distanceMiles
        : fallbackMeters / 1609.344;
    final mins = result.duration.inMinutes > 0
        ? result.duration.inMinutes
        : (miles * 2.5).ceil().clamp(1, 99);

    if (!mounted) return;
    setState(() {
      _distanceMiles = miles;
      _etaMinutes = mins;
      _routePoints = result.points.isNotEmpty ? result.points : [_currentLoc, _storeLoc];
    });
  }

  Future<void> _startInAppTrip() async {
    HapticFeedback.heavyImpact();
    setState(() => _tripStarted = true);

    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({
        'status': 'headingToStore',
        'tripStartedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLoc, 16.2),
    );
  }

  Future<void> _openExternalGoogleMaps() async {
    HapticFeedback.lightImpact();
    final navUri = Uri.parse(
      'google.navigation:q=${_storeLoc.latitude},${_storeLoc.longitude}&mode=d',
    );
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri);
    }
  }

  void _arrivedAtStoreAndPick() {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InStorePickingScreen(
          orderId: widget.orderId,
          storeName: widget.storeName,
          items: widget.items,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const cardBg = Color(0xFF1A1D24);

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentLoc, zoom: 14.5),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (c) async {
                  _mapController = c;
                  await c.setMapStyle(midnightTitaniumMapStyle);
                  if (mounted) setState(() => _mapReady = true);
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('store_pin'),
                    position: _storeLoc,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                    infoWindow: InfoWindow(
                      title: widget.storeName,
                      snippet: widget.storeAddress,
                    ),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('in_app_gold_glow'),
                    points: _routePoints,
                    color: gold.withValues(alpha: 0.35),
                    width: 9,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                  Polyline(
                    polylineId: const PolylineId('in_app_gold_core'),
                    points: _routePoints,
                    color: gold,
                    width: 5,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                },
              ),
            ),
          ),
          IgnorePointer(
            ignoring: _mapReady,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              curve: Curves.fastOutSlowIn,
              opacity: _mapReady ? 0.0 : 1.0,
              child: Container(color: const Color(0xFF121418)),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _tripStarted ? 'IN-APP NAVIGATION ACTIVE' : 'READY TO HEAD TO STORE',
                        style: const TextStyle(
                          color: gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '$_etaMinutes min • ${_distanceMiles.toStringAsFixed(1)} mi',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.storeAddress,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (!_tripStarted)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _startInAppTrip,
                              icon: const Icon(Icons.navigation_rounded, size: 20),
                              label: const Text(
                                'START TRIP',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: gold.withValues(alpha: 0.5)),
                              foregroundColor: gold,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _openExternalGoogleMaps,
                            child: const Icon(Icons.open_in_new_rounded, size: 20),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ADE80),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _arrivedAtStoreAndPick,
                        icon: const Icon(Icons.storefront_rounded, size: 20),
                        label: const Text(
                          'ARRIVED AT STORE • START PICKING',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
