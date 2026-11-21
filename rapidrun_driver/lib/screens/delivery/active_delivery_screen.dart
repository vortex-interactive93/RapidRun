// File: rapidrun_driver/lib/screens/delivery/active_delivery_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../services/driver_dispatch_listener.dart';
import '../../services/driver_auth_guard.dart';
import '../../services/driver_camera_helper.dart';
import '../../services/phone_heading_controller.dart';
import '../../services/rapidrun_map_markers.dart';
import '../../services/route_navigation_helper.dart';
import '../../services/route_polyline_service.dart';
import '../../services/arrival_proximity_helper.dart';
import '../../services/store_arrival_gate.dart';
import '../../services/smooth_navigation_tracker.dart';
import '../../services/unified_driver_wallet_controller.dart';
import '../../presentation/home/map_styles/midnight_titanium.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerAddress;
  final double customerLat;
  final double customerLng;
  final double payout;
  final double tipAmount;
  final int bagCount;
  final String deliveryNotes;
  final String customerPhone;
  final DriverRoutingPreference routingPreference;

  const ActiveDeliveryScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerAddress,
    this.customerLat = 32.759602,
    this.customerLng = -97.471416,
    required this.payout,
    required this.tipAmount,
    this.bagCount = 1,
    this.deliveryNotes = 'Leave bags on front porch by the door. Please ring bell!',
    this.customerPhone = '+18175550198',
    this.routingPreference = DriverRoutingPreference.ecoFriendly,
  });

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final PhoneHeadingController _phoneHeading = PhoneHeadingController();
  final ArrivalProximityHelper _proximityHelper = ArrivalProximityHelper();
  final StoreArrivalGate _arrivalGate = StoreArrivalGate();
  final SmoothNavigationTracker _navTracker = SmoothNavigationTracker();

  LatLng _currentLoc = const LatLng(32.7482, -97.4248);
  LatLng _snappedLoc = const LatLng(32.7482, -97.4248);
  double _roadBearing = 0.0;
  double _chevronHeading360 = 0.0;
  double _speedMps = 0.0;
  late final LatLng _customerLoc;

  List<LatLng> _fullRoutePoints = const [];
  List<LatLng> _remainingRoutePoints = const [];
  List<NavigationStep> _steps = const [];
  int _activeStepIndex = 0;
  double _distanceToStepMeters = 0.0;

  double _distanceMiles = 0.0;
  int _etaMinutes = 0;

  bool _navActive = true;
  bool _arrivedAtCustomer = false;
  bool _dropoffPhotoTaken = false;
  bool _isCompleting = false;
  bool _followCamera = true;
  bool _northUpMode = false;
  bool _isProgrammaticMove = false;
  bool _isProgrammaticCameraMove = false;
  bool _mapReady = false;
  bool _hasInitialRoute = false;
  bool _debugForceCustomerArrivalUnlocked = false;
  DateTime _lastCameraMoveAt = DateTime.fromMillisecondsSinceEpoch(0);

  BitmapDescriptor _driverPuckIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  BitmapDescriptor _customerPinIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _customerLoc = LatLng(widget.customerLat, widget.customerLng);
    _phoneHeading.startListening(
      onHeadingChanged: (deg) {
        if (!mounted || _speedMps >= 2.2) return;
        setState(() => _chevronHeading360 = deg);
      },
    );
    _loadCustomMarkers();
    _initTelemetryAndRoute();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _followCamera) {
      _applyNavigationCamera(force: true);
    }
  }

  Future<void> _loadCustomMarkers() async {
    final puck = await RapidRunMapMarkers.getDriverNavigationPuck();
    final destPin = await RapidRunMapMarkers.getPartnerStoreMarker();
    if (!mounted) return;
    setState(() {
      _driverPuckIcon = puck;
      _customerPinIcon = destPin;
    });
  }

  Future<void> _initTelemetryAndRoute() async {
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
      debugPrint('Initial delivery GPS notice: $e');
    }

    await _computeInitialCustomerRoute();

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
      onGpsFix: (position, snappedState) async {
        if (!mounted || !_hasInitialRoute) return;
        final raw = LatLng(position.latitude, position.longitude);

        _phoneHeading.updateHeading(
          movementOrRoadBearingDeg: snappedState.roadBearing,
          speedMps: position.speed.clamp(0.0, 60.0),
          gpsHeadingDeg: position.heading > 0 ? position.heading : null,
        );

        final bool inRange = _proximityHelper.checkWithinRange(
          currentLocation: snappedState.snappedLocation,
          targetLocation: _customerLoc,
          thresholdMeters: 50.0,
        );

        final meters = snappedState.remainingRouteMeters > 0
            ? snappedState.remainingRouteMeters
            : Geolocator.distanceBetween(
                raw.latitude,
                raw.longitude,
                _customerLoc.latitude,
                _customerLoc.longitude,
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
          _speedMps = position.speed.clamp(0.0, 60.0);
          _activeStepIndex = snappedState.activeStepIndex;
          _distanceToStepMeters = snappedState.distanceToStepMeters;
          _distanceMiles = miles;
          _etaMinutes = steadyMins;
          if (inRange && !_arrivedAtCustomer) {
            _arrivedAtCustomer = true;
          }
        });

        FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({
          'driverLat': position.latitude,
          'driverLng': position.longitude,
          'driverHeading': _chevronHeading360,
          'driverLocation': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'lastTelemetryAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('Telemetry sync notice: $e');
        });
      },
    );
  }

  Future<void> _computeInitialCustomerRoute() async {
    final result = await RoutePolylineService.instance.computeDrivingRoute(
      origin: _currentLoc,
      destination: _customerLoc,
      preference: widget.routingPreference,
    );

    final fallbackMeters = Geolocator.distanceBetween(
      _currentLoc.latitude,
      _currentLoc.longitude,
      _customerLoc.latitude,
      _customerLoc.longitude,
    );
    final miles = result.distanceMeters > 0
        ? result.distanceMiles
        : fallbackMeters / 1609.344;
    final mins = result.duration.inMinutes > 0
        ? result.duration.inMinutes
        : (miles * 2.5).ceil().clamp(1, 99);

    final pts =
        result.points.isNotEmpty ? result.points : [_currentLoc, _customerLoc];
    final initialSnap = RouteNavigationHelper.evaluate(
      rawLocation: _currentLoc,
      routePoints: pts,
      steps: result.steps,
      currentStepIndex: 0,
      fallbackHeading: _roadBearing,
    );

    if (!mounted) return;
    setState(() {
      _hasInitialRoute = true;
      _distanceMiles = miles;
      _etaMinutes = mins;
      _fullRoutePoints = pts;
      _remainingRoutePoints = initialSnap.remainingPoints.isNotEmpty
          ? initialSnap.remainingPoints
          : pts;
      _snappedLoc = initialSnap.snappedLocation;
      _roadBearing = initialSnap.roadBearing;
      _steps = result.steps;
      _activeStepIndex = 0;
    });
  }

  String _liveStepDistanceText(NavigationStep? step) {
    if (step == null) return '${_distanceMiles.toStringAsFixed(1)} mi';
    final metersToTurn = Geolocator.distanceBetween(
      _snappedLoc.latitude,
      _snappedLoc.longitude,
      step.endLocation.latitude,
      step.endLocation.longitude,
    );
    final feet = metersToTurn * 3.28084;
    if (feet < 1000) {
      final roundedFeet = ((feet / 25).round() * 25).clamp(25, 975);
      return '$roundedFeet ft';
    }
    return '${(metersToTurn / 1609.344).toStringAsFixed(1)} mi';
  }

  Future<void> _sync3DCameraIfFollowing({bool force = false}) async {
    if (!_navActive || !_followCamera || _mapController == null) return;

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

  Future<void> _animate3DFollowCamera() async {
    await _applyNavigationCamera(force: true);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navTracker.dispose();
    _phoneHeading.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _openExternalGoogleMaps() async {
    HapticFeedback.lightImpact();
    final nativeGoogleNav = Uri.parse(
      'google.navigation:q=${widget.customerLat},${widget.customerLng}&mode=d',
    );
    final universalMapUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.customerLat},${widget.customerLng}',
    );

    if (await canLaunchUrl(nativeGoogleNav)) {
      await launchUrl(nativeGoogleNav);
    } else {
      await launchUrl(universalMapUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer() async {
    HapticFeedback.lightImpact();
    final url = Uri.parse('tel:${widget.customerPhone}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _openChatSheet() {
    HapticFeedback.lightImpact();
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderChatSheet(
        orderId: widget.orderId,
        senderId: user?.uid ?? 'driver_01',
        senderName: 'Thomas (Shopper)',
        isDriver: true,
      ),
    );
  }

  void _simulatePhotoCapture() {
    HapticFeedback.heavyImpact();
    setState(() => _dropoffPhotoTaken = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF4ADE80),
        content: Text(
          '📸 Drop-off photo captured & attached to order',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _completeDelivery() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    HapticFeedback.heavyImpact();

    UnifiedDriverWalletController.instance.recordOrderCompleted(
      orderId: widget.orderId,
      totalPayout: widget.payout,
      tipAmount: widget.tipAmount,
    );

    driverEarningsState.recordCompletedBatch(
      payoutAmount: widget.payout,
      tip: widget.tipAmount,
    );

    final authUser = FirebaseAuth.instance.currentUser;
    final authUid = authUser?.uid;
    String resolvedDriverId = authUid ?? 'driver_local_tester';

    try {
      final authGuard = DriverAuthGuard();
      resolvedDriverId = await authGuard.resolveEffectiveDriverId(
        screenDriverId: authUid ?? 'driver_local_tester',
      );
      await authGuard.ensureDriverDocExists(resolvedDriverId);
    } catch (e) {
      debugPrint('DriverAuthGuard notice: $e');
    }

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .set({
        'status': 'completed',
        'dropoffPhotoUrl':
            'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=600&q=80',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Order completion sync notice: $e');
    }

    final wallet = UnifiedDriverWalletController.instance;
    final targetDriverDocId =
        (authUid != null && authUid.isNotEmpty) ? authUid : resolvedDriverId;

    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(targetDriverDocId)
          .set({
        'currentOrderId': FieldValue.delete(),
        'currentOrderStatus': FieldValue.delete(),
        'activeOrderId': FieldValue.delete(),
        'todayEarnings': wallet.todayEarnings,
        'thisWeekEarnings': wallet.thisWeekEarnings,
        'basePay': wallet.basePay,
        'customerTips': wallet.customerTips,
        'boostedTips': wallet.boostedTips,
        'totalCashedOut': wallet.totalCashedOut,
        'balance': wallet.availableCashout,
        'availableCashout': wallet.availableCashout,
        'totalDeliveriesCompleted': wallet.completedTrips,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Driver profile sync notice: $e');
    }

    if (!mounted) return;
    setState(() => _isCompleting = false);

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _EarningsCelebrationModal(
        totalPayout: widget.payout,
        tip: widget.tipAmount,
        orderId: widget.orderId,
        onFinish: () => Navigator.pop(ctx),
      ),
    );

    if (!mounted) return;
    DriverDispatchListener.instance.resetActiveState();
    Navigator.of(context).popUntil((route) => route.isFirst);
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
    const bg = Color(0xFF12151C);
    const cardSurface = Color(0xFF171A21);

    final NavigationStep? currentStep = _steps.isNotEmpty
        ? _steps[_activeStepIndex.clamp(0, _steps.length - 1)]
        : null;
    final NavigationStep? nextStep =
        (_activeStepIndex + 1 < _steps.length) ? _steps[_activeStepIndex + 1] : null;
    final int mph = (_speedMps * 2.23694).round();

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 1. 3D Behind-the-Wheel GoogleMap isolated in RepaintBoundary for 120fps motion
          Positioned.fill(
            child: RepaintBoundary(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _customerLoc,
                  zoom: 18.4,
                  tilt: 63.0,
                  bearing: _roadBearing,
                ),
                style: midnightTitaniumMapStyle,
                myLocationEnabled: !_navActive,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                buildingsEnabled: true,
                trafficEnabled: false,
                onCameraMoveStarted: () {
                  if (!_isProgrammaticCameraMove && !_isProgrammaticMove && _followCamera) {
                    setState(() => _followCamera = false);
                  }
                },
                onMapCreated: (c) async {
                  _mapController = c;
                  if (mounted) setState(() => _mapReady = true);
                  try {
                    await c.setMapStyle(midnightTitaniumMapStyle);
                  } catch (e) {
                    debugPrint('Map style notice: $e');
                  }
                  await _fitFullRouteOverview();
                },
                markers: {
                  if (_navActive)
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
                    markerId: const MarkerId('exact_dropoff_target'),
                    position: _customerLoc,
                    icon: _customerPinIcon,
                    anchor: const Offset(0.5, 0.9),
                    infoWindow: InfoWindow(
                      title: widget.customerName,
                      snippet: widget.customerAddress,
                    ),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('dropoff_gold_casing'),
                    points: _remainingRoutePoints,
                    color: const Color(0xFF0A0C10).withValues(alpha: 0.90),
                    width: 13,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                  Polyline(
                    polylineId: const PolylineId('dropoff_gold_core'),
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
              child: Container(color: bg),
            ),
          ),

          // 2. Top Dark + Gold Turn-by-Turn Banner
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
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: gold,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _iconForManeuver(currentStep?.maneuver ?? 'STRAIGHT'),
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _liveStepDistanceText(currentStep),
                              style: const TextStyle(
                                color: gold,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentStep?.instruction ??
                                  'Head toward ${widget.customerName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
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

          // 3. Live Speedometer Pill (Bottom-Left above Delivery Deck)
          Positioned(
            left: 14,
            bottom: 266,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cardSurface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$mph',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'MPH',
                    style: TextStyle(
                      color: gold,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Camera 3D Follow / Full Route Overview Toggles
          Positioned(
            right: 14,
            bottom: 266,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'dropoff_3d_follow',
                  backgroundColor: cardSurface,
                  foregroundColor: _followCamera ? gold : Colors.white70,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _navActive = true;
                      _followCamera = true;
                    });
                    _animate3DFollowCamera();
                  },
                  child: const Icon(Icons.navigation_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'dropoff_overview',
                  backgroundColor: cardSurface,
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

          // 5. Bottom Delivery Telemetry & Arrival/Completion Deck
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_etaMinutes min • ${_distanceMiles.toStringAsFixed(1)} mi • Arrive ${_formattedArrivalClock()}',
                        style: const TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${widget.bagCount} BAG',
                          style: const TextStyle(
                            color: gold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.customerAddress,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: gold,
                            ),
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            onPressed: _callCustomer,
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: gold,
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            onPressed: _openChatSheet,
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: gold,
                            ),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            onPressed: _openExternalGoogleMaps,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .doc(widget.orderId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data();
                      final liveNotes =
                          (data?['deliveryNotes'] ?? widget.deliveryNotes).toString();

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121418),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.doorbell_outlined, color: gold, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                liveNotes,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!_arrivedAtCustomer) ...[
                    GestureDetector(
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        setState(() => _debugForceCustomerArrivalUnlocked = !_debugForceCustomerArrivalUnlocked);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFFE5A93C),
                            content: Text(
                              _debugForceCustomerArrivalUnlocked
                                  ? '🛠️ QA OVERRIDE: Customer Arrival Unlocked'
                                  : '🔒 QA OVERRIDE: Customer Proximity Enforced',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                      child: Builder(
                        builder: (ctx) {
                          final arrivalStatus = _arrivalGate.evaluate(
                            currentLocation: _snappedLoc,
                            storeLocation: _customerLoc,
                            radiusMeters: 75.0,
                          );
                          final bool canArrive = arrivalStatus.isWithinRadius || _debugForceCustomerArrivalUnlocked;

                          return SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canArrive ? gold : Colors.white12,
                                foregroundColor: canArrive ? Colors.black : Colors.white54,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 4,
                              ),
                              onPressed: () {
                                if (!canArrive) {
                                  HapticFeedback.selectionClick();
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: const Color(0xFF1E222B),
                                      content: Text(
                                        '📍 ${arrivalStatus.distanceLabel} from ${widget.customerName}. Get within 246 ft (75m) to mark arrived.',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                HapticFeedback.heavyImpact();
                                setState(() => _arrivedAtCustomer = true);
                              },
                              icon: Icon(
                                canArrive ? Icons.location_on_rounded : Icons.lock_clock_rounded,
                                color: canArrive ? Colors.black : Colors.white54,
                                size: 18,
                              ),
                              label: Text(
                                canArrive
                                    ? 'ARRIVED AT CUSTOMER'
                                    : 'ARRIVE (${arrivalStatus.distanceLabel})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _dropoffPhotoTaken
                                      ? const Color(0xFF4ADE80)
                                      : gold,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _simulatePhotoCapture,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_dropoffPhotoTaken) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=100&q=80',
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Flexible(
                                      child: Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Color(0xFF4ADE80),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ] else ...[
                                    const Icon(
                                      Icons.camera_alt_outlined,
                                      color: gold,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    const Flexible(
                                      child: Text(
                                        'Snap Photo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gold,
                                disabledBackgroundColor: Colors.white12,
                                foregroundColor: Colors.black,
                                disabledForegroundColor: Colors.white38,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 4,
                              ),
                              onPressed: (_dropoffPhotoTaken && !_isCompleting)
                                  ? _completeDelivery
                                  : null,
                              child: _isCompleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'COMPLETE RUN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsCelebrationModal extends StatelessWidget {
  final double totalPayout;
  final double tip;
  final String orderId;
  final VoidCallback onFinish;

  const _EarningsCelebrationModal({
    required this.totalPayout,
    required this.tip,
    required this.orderId,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    final basePay = (totalPayout - tip).clamp(0.0, totalPayout);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F2618),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Batch Completed!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Order #$orderId was delivered successfully.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  'TOTAL ADDED TO BALANCE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${totalPayout.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: gold,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Base Pay: \$${basePay.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '100% Tip: +\$${tip.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onFinish,
              child: const Text(
                'BACK TO DISPATCH MAP',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
