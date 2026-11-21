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
import '../../services/driver_camera_helper.dart';
import '../../services/nav_voice_guidance.dart';
import '../../services/phone_heading_controller.dart';
import '../../services/rapidrun_map_markers.dart';
import '../../services/route_navigation_helper.dart';
import '../../services/route_polyline_service.dart';
import '../../services/smooth_navigation_tracker.dart';
import '../../services/store_arrival_gate.dart';
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
    this.storeAddress = 'Bath & Body Works • Ridgmar Plaza, Fort Worth, TX',
    this.storeLat = 32.7478,
    this.storeLng = -97.4278,
    this.routingPreference = DriverRoutingPreference.ecoFriendly,
    required this.items,
  });

  @override
  State<StartTripToStoreScreen> createState() => _StartTripToStoreScreenState();
}

class _StartTripToStoreScreenState extends State<StartTripToStoreScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final PhoneHeadingController _phoneHeading = PhoneHeadingController();
  final SmoothNavigationTracker _navTracker = SmoothNavigationTracker();

  LatLng _currentLoc = const LatLng(32.7568, -97.4768);
  LatLng _snappedLoc = const LatLng(32.7568, -97.4768);
  double _chevronHeading360 = 0.0;
  double _speedMps = 0.0;
  late final LatLng _storeLoc;

  List<LatLng> _fullRoutePoints = const [];
  List<LatLng> _remainingRoutePoints = const [];
  List<NavigationStep> _steps = const [];
  int _activeStepIndex = 0;
  double _distanceToStepMeters = 0.0;

  bool _tripStarted = false;
  bool _followCamera = true;
  bool _northUpMode = false;
  bool _muted = false;
  bool _mapReady = false;
  bool _hasInitialRoute = false;
  bool _debugForceArrivalUnlocked = false;
  bool _isProgrammaticCameraMove = false;
  double _distanceMiles = 0.0;
  int _etaMinutes = 0;
  DateTime _lastCameraMoveAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRerouteAt = DateTime.fromMillisecondsSinceEpoch(0);

  final StoreArrivalGate _arrivalGate = StoreArrivalGate();

  BitmapDescriptor _storeMarkerIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  BitmapDescriptor _driverPuckIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _storeLoc = LatLng(widget.storeLat, widget.storeLng);
    NavVoiceGuidance.instance.resetTrip();
    _loadMarkers();
    _initLocationAndRoute();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _tripStarted && _followCamera) {
      _applyNavigationCamera(force: true);
    }
  }

  Future<void> _loadMarkers() async {
    final storePin = await RapidRunMapMarkers.getPartnerStoreMarker();
    final puckPin = await RapidRunMapMarkers.getDriverNavigationPuck();
    if (!mounted) return;
    setState(() {
      _storeMarkerIcon = storePin;
      _driverPuckIcon = puckPin;
    });
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
        _snappedLoc = _currentLoc;
        if (pos.heading > 0) _chevronHeading360 = pos.heading % 360.0;
      }
    } catch (e) {
      debugPrint('Initial store GPS notice: $e');
    }

    await _computeRoute(fromOrigin: _currentLoc);

    _phoneHeading.startListening(
      onHeadingChanged: (deg) {
        if (!mounted || _speedMps >= 2.2) return;
        setState(() => _chevronHeading360 = deg);
      },
    );

    _navTracker.start(
      vsync: this,
      initialLocation: _snappedLoc,
      initialHeading: _chevronHeading360,
      getFullRoutePoints: () => _fullRoutePoints,
      getSteps: () => _steps,
      getActiveStepIndex: () => _activeStepIndex,
      onFrameTick: (smoothLoc, smoothHeading) {
        if (!mounted) return;
        final displayHeading = (_navTracker.currentSpeedMps < 2.2)
            ? _phoneHeading.fusedHeadingDeg
            : smoothHeading;

        setState(() {
          _snappedLoc = smoothLoc;
          _chevronHeading360 = displayHeading;
        });

        _sync3DCameraIfFollowing();
      },
      onGpsFix: (pos, snappedState) async {
        if (!mounted || !_hasInitialRoute) return;
        final raw = LatLng(pos.latitude, pos.longitude);

        _phoneHeading.updateHeading(
          movementOrRoadBearingDeg: snappedState.roadBearing,
          speedMps: pos.speed.clamp(0.0, 60.0),
          gpsHeadingDeg: pos.heading > 0 ? pos.heading : null,
        );

        final now = DateTime.now();
        if (_tripStarted &&
            snappedState.distanceToRouteMeters > 110.0 &&
            now.difference(_lastRerouteAt).inSeconds >= 10) {
          _lastRerouteAt = now;
          await _computeRoute(fromOrigin: raw);
          return;
        }

        final meters = snappedState.remainingRouteMeters > 0
            ? snappedState.remainingRouteMeters
            : Geolocator.distanceBetween(
                raw.latitude,
                raw.longitude,
                _storeLoc.latitude,
                _storeLoc.longitude,
              );
        final miles = meters / 1609.344;
        final rawMins = (miles * 2.3).ceil().clamp(1, 99);
        final steadyMins = _etaMinutes == 0
            ? rawMins
            : ((_etaMinutes * 0.7) + (rawMins * 0.3)).round().clamp(1, 99);

        setState(() {
          _currentLoc = raw;
          _remainingRoutePoints = snappedState.remainingPoints.isNotEmpty
              ? snappedState.remainingPoints
              : _fullRoutePoints;
          _speedMps = pos.speed.clamp(0.0, 60.0);
          _activeStepIndex = snappedState.activeStepIndex;
          _distanceToStepMeters = snappedState.distanceToStepMeters;
          _distanceMiles = miles;
          _etaMinutes = steadyMins;
        });

        if (_steps.isNotEmpty) {
          final activeStep =
              _steps[_activeStepIndex.clamp(0, _steps.length - 1)];
          NavVoiceGuidance.instance.onStepUpdated(
            stepIndex: _activeStepIndex,
            instruction: activeStep.instruction,
            distanceToStepMeters: snappedState.distanceToStepMeters,
          );
        }

        FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({
          'driverLat': pos.latitude,
          'driverLng': pos.longitude,
          'driverHeading': _chevronHeading360,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      },
    );
  }

  Future<void> _computeRoute({required LatLng fromOrigin}) async {
    final result = await RoutePolylineService.instance.computeDrivingRoute(
      origin: fromOrigin,
      destination: _storeLoc,
      preference: widget.routingPreference,
    );

    final fallbackMeters = Geolocator.distanceBetween(
      fromOrigin.latitude,
      fromOrigin.longitude,
      _storeLoc.latitude,
      _storeLoc.longitude,
    );
    final miles = result.distanceMeters > 0
        ? result.distanceMiles
        : fallbackMeters / 1609.344;
    final mins = result.duration.inMinutes > 0
        ? result.duration.inMinutes
        : (miles * 2.3).ceil().clamp(1, 99);

    final pts =
        result.points.isNotEmpty ? result.points : [fromOrigin, _storeLoc];

    if (!mounted) return;
    setState(() {
      _hasInitialRoute = true;
      _distanceMiles = miles;
      _etaMinutes = mins;
      _fullRoutePoints = pts;
      _remainingRoutePoints = pts;
      _snappedLoc = fromOrigin;
      _steps = result.steps;
      _activeStepIndex = 0;
    });
  }

  String _formattedStepDistance(NavigationStep? step) {
    if (step == null) return '${_distanceMiles.toStringAsFixed(1)} mi';
    final meters = _distanceToStepMeters > 0
        ? _distanceToStepMeters
        : Geolocator.distanceBetween(
            _snappedLoc.latitude,
            _snappedLoc.longitude,
            step.endLocation.latitude,
            step.endLocation.longitude,
          );
    final feet = meters * 3.28084;
    if (feet < 1000) {
      final roundedFeet = ((feet / 25).round() * 25).clamp(25, 975);
      return '$roundedFeet ft';
    }
    return '${(meters / 1609.344).toStringAsFixed(1)} mi';
  }

  Future<void> _sync3DCameraIfFollowing({bool force = false}) async {
    if (!_tripStarted || !_followCamera || _mapController == null) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastCameraMoveAt).inMilliseconds < 180) {
      return;
    }
    _lastCameraMoveAt = now;

    final cameraPos = DriverCameraHelper.buildNavigationCamera(
      driverLocation: _snappedLoc,
      headingDegrees: _chevronHeading360,
      northUpMode: _northUpMode,
      zoom3D: 17.9,
      tilt3D: 58.0,
      lookAheadMeters: 95.0,
    );

    _isProgrammaticCameraMove = true;
    try {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(cameraPos),
      );
    } finally {
      _isProgrammaticCameraMove = false;
    }
  }

  Future<void> _applyNavigationCamera({bool force = false}) async {
    await _sync3DCameraIfFollowing(force: force);
  }

  Future<void> _fitFullRouteOverview() async {
    if (_remainingRoutePoints.length < 2 || _mapController == null) return;
    double minLat = _remainingRoutePoints.first.latitude;
    double maxLat = _remainingRoutePoints.first.latitude;
    double minLng = _remainingRoutePoints.first.longitude;
    double maxLng = _remainingRoutePoints.first.longitude;

    for (final p in _remainingRoutePoints) {
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
      _northUpMode = false;
    });

    await _sync3DCameraIfFollowing(force: true);

    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({
        'status': 'headingToStore',
        'tripStartedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
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

  void _handleArrivedAtStoreTap() {
    final status = _arrivalGate.evaluate(
      currentLocation: _snappedLoc,
      storeLocation: _storeLoc,
      radiusMeters: 75.0,
    );

    final canArrive = status.isWithinRadius || _debugForceArrivalUnlocked;
    if (!canArrive) {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E222B),
          content: Text(
            '📍 ${status.distanceLabel} from ${widget.storeName}. Get within 246 ft (75m) to mark arrived.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    _arrivedAtStoreAndPick();
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
    WidgetsBinding.instance.removeObserver(this);
    _navTracker.dispose();
    _phoneHeading.dispose();
    _mapController?.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const urgencyAmber = Color(0xFFFFC857);
    const cardBg = Color(0xFF171A21);

    final NavigationStep? currentStep = _steps.isNotEmpty
        ? _steps[_activeStepIndex.clamp(0, _steps.length - 1)]
        : null;
    final NavigationStep? nextStep =
        (_activeStepIndex + 1 < _steps.length) ? _steps[_activeStepIndex + 1] : null;

    final bool turnImminent =
        _distanceToStepMeters > 0 && _distanceToStepMeters <= 68.0;
    final int mph = (_speedMps * 2.23694).round();
    final String cardinal = DriverCameraHelper.cardinalDirection(_chevronHeading360);

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      body: Stack(
        children: [
          // RepaintBoundary isolates GoogleMap so 60fps marker & camera moves don't repaint HUD
          Positioned.fill(
            child: RepaintBoundary(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentLoc, zoom: 15.0),
                style: midnightTitaniumMapStyle,
                myLocationEnabled: !_tripStarted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                buildingsEnabled: true,
                trafficEnabled: false,
                onCameraMoveStarted: () {
                  if (!_isProgrammaticCameraMove && _tripStarted && _followCamera) {
                    setState(() => _followCamera = false);
                  }
                },
                onMapCreated: (c) async {
                  _mapController = c;
                  if (mounted) setState(() => _mapReady = true);
                  await _fitFullRouteOverview();
                },
                circles: {
                  Circle(
                    circleId: const CircleId('store_arrival_geofence'),
                    center: _storeLoc,
                    radius: 50.0,
                    fillColor: gold.withValues(alpha: 0.10),
                    strokeColor: gold.withValues(alpha: 0.55),
                    strokeWidth: 2,
                  ),
                },
                markers: {
                  if (_tripStarted)
                    Marker(
                      markerId: const MarkerId('rapidrun_driver_puck'),
                      position: _snappedLoc,
                      icon: _driverPuckIcon,
                      flat: true,
                      rotation: _chevronHeading360,
                      anchor: const Offset(0.5, 0.5),
                      zIndexInt: 10,
                    ),
                  Marker(
                    markerId: const MarkerId('rapidrun_partner_store'),
                    position: _storeLoc,
                    icon: _storeMarkerIcon,
                    anchor: const Offset(0.5, 0.9),
                    infoWindow: InfoWindow(
                      title: widget.storeName,
                      snippet: 'RapidRun Partner Store • ${widget.storeAddress}',
                    ),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('in_app_gold_casing'),
                    points: _remainingRoutePoints,
                    color: const Color(0xFF0A0C10).withValues(alpha: 0.90),
                    width: 13,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                  Polyline(
                    polylineId: const PolylineId('in_app_gold_core'),
                    points: _remainingRoutePoints,
                    color: const Color(0xFFE6B450),
                    width: 6,
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
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.fastOutSlowIn,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171E).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: turnImminent ? urgencyAmber : gold.withValues(alpha: 0.45),
                      width: turnImminent ? 1.8 : 1.2,
                    ),
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
                          color: turnImminent ? urgencyAmber : gold,
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
                            Row(
                              children: [
                                Text(
                                  _formattedStepDistance(currentStep),
                                  style: TextStyle(
                                    color: turnImminent ? urgencyAmber : gold,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (turnImminent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: urgencyAmber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'TURN NOW',
                                      style: TextStyle(
                                        color: urgencyAmber,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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

          Positioned(
            left: 14,
            bottom: 215,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$mph',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        'MPH',
                        style: TextStyle(
                          color: gold,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    width: 1,
                    height: 24,
                    color: Colors.white12,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cardinal,
                        style: const TextStyle(
                          color: gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '${_chevronHeading360.round()}°',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 14,
            bottom: 215,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'north_3d_toggle',
                  backgroundColor: cardBg,
                  foregroundColor: _northUpMode ? const Color(0xFF38BDF8) : gold,
                  tooltip: _northUpMode ? 'Switch to 3D Heading-Up' : 'Switch to North-Up',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _northUpMode = !_northUpMode;
                      _followCamera = true;
                    });
                    _applyNavigationCamera(force: true);
                  },
                  child: Icon(
                    _northUpMode ? Icons.explore_rounded : Icons.view_in_ar_rounded,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'voice_mute_toggle',
                  backgroundColor: cardBg,
                  foregroundColor: _muted ? Colors.white38 : gold,
                  onPressed: () {
                    NavVoiceGuidance.instance.toggleMute();
                    setState(() => _muted = NavVoiceGuidance.instance.muted);
                  },
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'recenter_3d_cam',
                  backgroundColor: cardBg,
                  foregroundColor: _followCamera ? gold : Colors.white70,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _followCamera = true);
                    _applyNavigationCamera(force: true);
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
                          _northUpMode ? 'NORTH-UP' : widget.routingPreference.name.toUpperCase(),
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
                          child: GestureDetector(
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              setState(() => _debugForceArrivalUnlocked = !_debugForceArrivalUnlocked);
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFFE5A93C),
                                  content: Text(
                                    _debugForceArrivalUnlocked
                                        ? '🛠️ QA OVERRIDE: Arrival Unlocked'
                                        : '🔒 QA OVERRIDE: Proximity Gate Enforced',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                            child: Builder(
                              builder: (ctx) {
                                final arrivalStatus = _arrivalGate.evaluate(
                                  currentLocation: _snappedLoc,
                                  storeLocation: _storeLoc,
                                  radiusMeters: 75.0,
                                );
                                final bool canConfirm = arrivalStatus.isWithinRadius || _debugForceArrivalUnlocked;

                                return SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canConfirm ? const Color(0xFF4ADE80) : Colors.white12,
                                      foregroundColor: canConfirm ? Colors.black : Colors.white54,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _handleArrivedAtStoreTap,
                                    icon: Icon(
                                      canConfirm ? Icons.storefront_rounded : Icons.lock_clock_rounded,
                                      size: 20,
                                    ),
                                    label: Text(
                                      canConfirm
                                          ? 'ARRIVED AT STORE • START PICKING'
                                          : 'ARRIVE (${arrivalStatus.distanceLabel})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12.5,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                );
                              },
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
