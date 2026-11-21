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
import '../../services/route_polyline_service.dart';
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

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;

  LatLng _currentLoc = const LatLng(32.7482, -97.4248);
  double _heading = 0.0;
  late final LatLng _customerLoc;

  List<LatLng> _routePoints = const [];
  List<NavigationStep> _steps = const [];
  double _distanceMiles = 0.0;
  int _etaMinutes = 0;

  bool _arrivedAtCustomer = false;
  bool _dropoffPhotoTaken = false;
  bool _isCompleting = false;
  bool _followCamera = false;
  bool _isProgrammaticMove = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _customerLoc = LatLng(widget.customerLat, widget.customerLng);
    _initTelemetryAndRoute();
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
        _heading = pos.heading;
      }
    } catch (e) {
      debugPrint('Initial delivery GPS notice: $e');
    }

    await _recalculateCustomerRoute();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((position) async {
      if (!mounted) return;
      final updated = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLoc = updated;
        if (position.heading > 0) _heading = position.heading;
      });

      FirebaseFirestore.instance.collection('orders').doc(widget.orderId).set({
        'driverLat': position.latitude,
        'driverLng': position.longitude,
        'driverHeading': position.heading,
        'driverLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'lastTelemetryAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('Telemetry sync notice: $e');
      });

      if (!_arrivedAtCustomer && _followCamera) {
        _animate3DFollowCamera();
      }
      await _recalculateCustomerRoute();
    });
  }

  Future<void> _recalculateCustomerRoute() async {
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

    if (!mounted) return;
    setState(() {
      _distanceMiles = miles;
      _etaMinutes = mins;
      _routePoints =
          result.points.isNotEmpty ? result.points : [_currentLoc, _customerLoc];
      _steps = result.steps;
    });
  }

  String _liveStepDistanceText(NavigationStep? step) {
    if (step == null) return '${_distanceMiles.toStringAsFixed(1)} mi';
    final metersToTurn = Geolocator.distanceBetween(
      _currentLoc.latitude,
      _currentLoc.longitude,
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

  @override
  void dispose() {
    _positionSub?.cancel();
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
    const bg = Color(0xFF141414);
    const cardSurface = Color(0xFF171A21);

    final NavigationStep? currentStep = _steps.isNotEmpty ? _steps.first : null;
    final NavigationStep? nextStep = _steps.length > 1 ? _steps[1] : null;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _customerLoc,
                  zoom: 15.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                trafficEnabled: true,
                onCameraMoveStarted: () {
                  if (!_isProgrammaticMove && _followCamera) {
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
                    markerId: const MarkerId('exact_dropoff_target'),
                    position: _customerLoc,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                    infoWindow: InfoWindow(
                      title: widget.customerName,
                      snippet: widget.customerAddress,
                    ),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('dropoff_gold_glow'),
                    points: _routePoints,
                    color: gold.withValues(alpha: 0.35),
                    width: 10,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                  Polyline(
                    polylineId: const PolylineId('dropoff_gold_core'),
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
              child: Container(color: bg),
            ),
          ),

          // Top Dark + Gold Turn-by-Turn Banner
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

          // Camera 3D Follow / Full Route Toggles
          Positioned(
            right: 14,
            bottom: 270,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'dropoff_3d_follow',
                  backgroundColor: cardSurface,
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

          // Bottom Delivery Telemetry & Arrival/Completion Deck
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
                      final liveNotes = (data?['deliveryNotes'] ?? widget.deliveryNotes).toString();

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
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.25),
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
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          setState(() => _arrivedAtCustomer = true);
                        },
                        icon: const Icon(Icons.location_on_rounded, color: Colors.black, size: 18),
                        label: const Text(
                          'ARRIVED AT CUSTOMER',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.5),
                        ),
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
                                  color: _dropoffPhotoTaken ? const Color(0xFF4ADE80) : gold,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                                    const Icon(Icons.camera_alt_outlined, color: gold, size: 16),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                              ),
                              onPressed: (_dropoffPhotoTaken && !_isCompleting) ? _completeDelivery : null,
                              child: _isCompleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
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
            child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Batch Completed!',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
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
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
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
                    Text('Base Pay: \$${basePay.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      '100% Tip: +\$${tip.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onFinish,
              child: const Text(
                'BACK TO DISPATCH MAP',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
