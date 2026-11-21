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
  double _heading = 0.0;
  late final LatLng _storeLoc;
  List<LatLng> _routePoints = const [];
  List<NavigationStep> _steps = const [];

  bool _tripStarted = false;
  bool _followCamera = true;
  bool _isProgrammaticMove = false;
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
        _heading = pos.heading;
      }
    } catch (e) {
      debugPrint('Initial store GPS notice: $e');
    }

    await _recalculateRoute();

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 12,
      ),
    ).listen((pos) async {
      if (!mounted) return;
      final updated = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentLoc = updated;
        if (pos.heading > 0) _heading = pos.heading;
      });

      FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({
        'driverLat': pos.latitude,
        'driverLng': pos.longitude,
        'driverHeading': pos.heading,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});

      if (_tripStarted && _followCamera) {
        _animate3DFollowCamera();
      }
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
      _routePoints =
          result.points.isNotEmpty ? result.points : [_currentLoc, _storeLoc];
      _steps = result.steps;
    });
  }

  Future<void> _animate3DFollowCamera() async {
    if (_mapController == null) return;
    _isProgrammaticMove = true;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLoc,
          zoom: 18.0,
          tilt: 58.0,
          bearing: _heading,
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    _isProgrammaticMove = false;
  }

  Future<void> _fitFullRouteOverview() async {
    if (_routePoints.length < 2 || _mapController == null) return;
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (final p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.003, minLng - 0.003),
          northeast: LatLng(maxLat + 0.003, maxLng + 0.003),
        ),
        90.0,
      ),
    );
  }

  Future<void> _startInAppTrip() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _tripStarted = true;
      _followCamera = true;
    });

    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({
        'status': 'headingToStore',
        'tripStartedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    await _animate3DFollowCamera();
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

  IconData _iconForManeuver(String maneuver) {
    final m = maneuver.toUpperCase();
    if (m.contains('LEFT')) return Icons.turn_left_rounded;
    if (m.contains('RIGHT')) return Icons.turn_right_rounded;
    if (m.contains('MERGE') || m.contains('RAMP')) return Icons.merge_rounded;
    if (m.contains('ROUNDABOUT')) return Icons.roundabout_right_rounded;
    if (m.contains('UTURN')) return Icons.u_turn_left_rounded;
    return Icons.straight_rounded;
  }

  String _formattedArrivalClock() {
    final eta = DateTime.now().add(Duration(minutes: _etaMinutes));
    final hour12 = eta.hour == 0 ? 12 : (eta.hour > 12 ? eta.hour - 12 : eta.hour);
    final mins = eta.minute.toString().padLeft(2, '0');
    final suffix = eta.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$mins $suffix';
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
    const cardBg = Color(0xFF171A21);

    final NavigationStep? currentStep = _steps.isNotEmpty ? _steps.first : null;
    final NavigationStep? nextStep = _steps.length > 1 ? _steps[1] : null;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      body: Stack(
        children: [
          // 1. Full-bleed Midnight Titanium Map isolated inside RepaintBoundary
          Positioned.fill(
            child: RepaintBoundary(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentLoc, zoom: 14.5),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                buildingsEnabled: true,
                trafficEnabled: true,
                onCameraMoveStarted: () {
                  if (!_isProgrammaticMove && _tripStarted && _followCamera) {
                    setState(() => _followCamera = false);
                  }
                },
                onMapCreated: (c) async {
                  _mapController = c;
                  await c.setMapStyle(midnightTitaniumMapStyle);
                  if (mounted) setState(() => _mapReady = true);
                  await _fitFullRouteOverview();
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('driver_vehicle_puck'),
                    position: _currentLoc,
                    rotation: _heading,
                    flat: true,
                    anchor: const Offset(0.5, 0.5),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                  ),
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
                    width: 10,
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

          // 2. Top Turn-by-Turn Maneuver HUD (Uber/Spark-style Dark + Gold Banner)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171E).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: gold.withValues(alpha: 0.45), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: gold,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _iconForManeuver(currentStep?.maneuver ?? 'STRAIGHT'),
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStep?.formattedDistance ??
                                  '${_distanceMiles.toStringAsFixed(1)} mi',
                              style: const TextStyle(
                                color: gold,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentStep?.instruction ??
                                  'Head toward ${widget.storeName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (nextStep != null)
                  Container(
                    margin: const EdgeInsets.only(left: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E222B).withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'THEN ',
                          style: TextStyle(
                            color: gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Icon(
                          _iconForManeuver(nextStep.maneuver),
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            nextStep.instruction,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 3. Floating Right Camera Controls (Recenter 3D Follow vs. Full Route Overview)
          Positioned(
            right: 14,
            bottom: 215,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_3d_cam',
                  backgroundColor: cardBg,
                  foregroundColor: _followCamera ? gold : Colors.white70,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _followCamera = true);
                    _animate3DFollowCamera();
                  },
                  child: const Icon(Icons.navigation_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'overview_route_cam',
                  backgroundColor: cardBg,
                  foregroundColor: Colors.white70,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _followCamera = false);
                    _fitFullRouteOverview();
                  },
                  child: const Icon(Icons.alt_route_rounded, size: 20),
                ),
              ],
            ),
          ),

          // 4. Bottom Driver Navigation Telemetry & Action Deck
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
                      Row(
                        children: [
                          Text(
                            '$_etaMinutes min',
                            style: const TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${_distanceMiles.toStringAsFixed(1)} mi • Arrive ${_formattedArrivalClock()}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.routingPreference.name.toUpperCase(),
                          style: const TextStyle(
                            color: gold,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pickup: ${widget.storeName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    widget.storeAddress,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
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
                                'START IN-APP NAVIGATION',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  letterSpacing: 0.5,
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
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
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
                                  fontSize: 13,
                                  letterSpacing: 0.4,
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
