// File: rapidrun_driver/lib/screens/driver_home_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

import '../presentation/home/map_styles/midnight_titanium.dart';
import '../presentation/home/tactical_flight_deck.dart';
import '../presentation/home/tactical_demand_deck.dart';
import '../services/driver_dispatch_listener.dart';
import '../services/route_polyline_service.dart';
import '../widgets/radar/driver_shift_adjustment_sheet.dart';
import '../widgets/order/transparent_batch_offer_card.dart';
import 'shell/driver_drawer.dart';
import 'shopping/in_store_picking_screen.dart';
import 'delivery/active_delivery_screen.dart';
import 'wallet/driver_cashout_sheet.dart';
import 'earnings/earnings_dashboard_screen.dart';
import 'driver_menu/trip_history_screen.dart';
import 'driver_menu/vehicle_compliance_screen.dart';
import 'driver_menu/driver_settings_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final String driverId;
  const DriverHomeScreen({super.key, required this.driverId});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _map;

  bool _online = false;
  DateTime? _availableUntil;
  bool _mapReady = false;
  double _todayEarnings = 0.0;
  int _completedTrips = 0;
  Timer? _countdownTimer;

  final CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(32.7568, -97.4768),
    zoom: 14.5,
  );

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tipBoostSub;
  Set<Polyline> _activeOfferPolylines = {};
  DriverRoutingPreference _currentRoutePref = DriverRoutingPreference.ecoFriendly;

  final Set<Polygon> _surgePolygons = {
    Polygon(
      polygonId: const PolygonId('westover_surge_hex'),
      points: const [
        LatLng(32.7530, -97.4320),
        LatLng(32.7500, -97.4220),
        LatLng(32.7440, -97.4200),
        LatLng(32.7400, -97.4280),
        LatLng(32.7430, -97.4370),
        LatLng(32.7500, -97.4380),
      ],
      fillColor: const Color(0x28E6B450),
      strokeColor: const Color(0x88E6B450),
      strokeWidth: 2,
    ),
  };

  @override
  void initState() {
    super.initState();
    _setSystemUI();
    _subscribeDriver();
    _listenForIncomingTipBoosts();
    DriverDispatchListener.instance.activeOfferNotifier.addListener(_handleOfferStateChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      DriverDispatchListener.instance.initializeAutoDispatch(context);
    });
  }

  void _handleOfferStateChange() {
    final offer = DriverDispatchListener.instance.activeOfferNotifier.value;
    if (offer != null) {
      _updateOfferRoute(offer);
    } else {
      _clearBatchOfferRoute();
    }
  }

  Future<void> _updateOfferRoute(
    Map<String, dynamic> offer, {
    DriverRoutingPreference? preference,
  }) async {
    if (preference != null) _currentRoutePref = preference;

    final double storeLat = (offer['storeLat'] as num?)?.toDouble() ?? 32.7482;
    final double storeLng = (offer['storeLng'] as num?)?.toDouble() ?? -97.4248;
    final double custLat = (offer['customerLat'] as num?)?.toDouble() ?? 32.7596;
    final double custLng = (offer['customerLng'] as num?)?.toDouble() ?? -97.4714;

    final storePoint = LatLng(storeLat, storeLng);
    final custPoint = LatLng(custLat, custLng);

    final routePoints = await RoutePolylineService.instance.getDrivingRoute(
      origin: storePoint,
      destination: custPoint,
      preference: _currentRoutePref,
    );

    if (!mounted) return;

    setState(() {
      _activeOfferPolylines = {
        Polyline(
          polylineId: const PolylineId('offer_route_glow'),
          points: routePoints,
          color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
          width: 8,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
        Polyline(
          polylineId: const PolylineId('offer_route_core'),
          points: routePoints,
          color: const Color(0xFFE5A93C),
          width: 4,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (final p in routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.002, minLng - 0.002),
          northeast: LatLng(maxLat + 0.002, maxLng + 0.002),
        ),
        80.0,
      ),
    );
  }

  void _clearBatchOfferRoute() {
    if (_activeOfferPolylines.isNotEmpty) {
      setState(() {
        _activeOfferPolylines.clear();
      });
    }
  }

  void _setSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF13151A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _subscribeDriver() {
    _driverSub = FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final newOnline = data['online'] == true;
      final earnings = (data['todayEarnings'] as num?)?.toDouble() ?? 0.0;
      final trips = (data['totalDeliveriesCompleted'] as num?)?.toInt() ?? 0;
      final boosted = (data['boostedTips'] as num?)?.toDouble() ?? 0.0;
      final ts = data['availableUntil'];
      DateTime? until;
      if (ts is Timestamp) until = ts.toDate();

      if (mounted) {
        setState(() {
          _online = newOnline;
          _availableUntil = until;
          _todayEarnings = earnings;
          _completedTrips = trips;
        });

        driverEarningsState.syncEarnings(earnings, trips, boosted: boosted);

        if (_online && _availableUntil != null) {
          _startCountdownTimer();
        } else if (!_online) {
          _countdownTimer?.cancel();
        }
      }
    });
  }

  final Set<String> _processedBoostTokens = {};

  void _listenForIncomingTipBoosts() {
    _tipBoostSub?.cancel();
    _tipBoostSub = FirebaseFirestore.instance
        .collection('orders')
        .where('driverId', isEqualTo: widget.driverId)
        .where('tipBoostPending', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final String token = data['boostToken']?.toString() ?? doc.id;
        final double incrementalBoost =
            (data['pendingBoostAmount'] as num?)?.toDouble() ??
            (data['tipBoost'] as num?)?.toDouble() ??
            0.0;

        // Guard against duplicate execution or re-entrancy snapshots
        if (_processedBoostTokens.contains(token) || incrementalBoost <= 0) {
          continue;
        }
        _processedBoostTokens.add(token);

        // 1. Immediately consume pending state and clear pendingBoostAmount on order
        await doc.reference.update({
          'tipBoostPending': false,
          'pendingBoostAmount': FieldValue.delete(),
        });

        // 2. Credit driver wallet document ONCE
        await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).set({
          'todayEarnings': FieldValue.increment(incrementalBoost),
          'balance': FieldValue.increment(incrementalBoost),
          'customerTips': FieldValue.increment(incrementalBoost),
          'boostedTips': FieldValue.increment(incrementalBoost),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. Update local reactive state
        driverEarningsState.recordTipBoost(incrementalBoost);

        // 4. Trigger celebration banner
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFE5A93C),
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.black, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CUSTOMER TIP BOOST! 🚀',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        Text(
                          'Customer added an extra +\$${incrementalBoost.toStringAsFixed(2)} for great service!',
                          style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    });
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (_availableUntil != null && DateTime.now().isAfter(_availableUntil!)) {
        _setOffline();
      } else {
        setState(() {});
      }
    });
  }

  /// Sets driver online with minimum 4 hours active time
  Future<void> _setOnlineWith4Hours() async {
    HapticFeedback.heavyImpact();
    final until = DateTime.now().add(const Duration(hours: 4));

    try {
      await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).set({
        'online': true,
        'active': true,
        'availableUntil': Timestamp.fromDate(until),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _online = true;
        _availableUntil = until;
      });
      _startCountdownTimer();
    } catch (e) {
      debugPrint('Error going online: $e');
    }
  }

  Future<void> _setOffline() async {
    HapticFeedback.heavyImpact();
    _countdownTimer?.cancel();

    try {
      await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).set({
        'online': false,
        'availableUntil': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _online = false;
        _availableUntil = null;
      });
    } catch (e) {
      debugPrint('Error going offline: $e');
    }
  }

  void _handleStatusTap() {
    if (!_online) {
      _setOnlineWith4Hours();
    } else {
      final remaining = _availableUntil?.difference(DateTime.now()) ?? const Duration(hours: 4);

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => DriverShiftAdjustmentSheet(
          remainingDuration: remaining,
          onAdjustRemaining: (newDuration) async {
            final newUntil = DateTime.now().add(newDuration);
            await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).set({
              'availableUntil': Timestamp.fromDate(newUntil),
            }, SetOptions(merge: true));
            setState(() => _availableUntil = newUntil);
          },
          onGoOffline: _setOffline,
        ),
      );
    }
  }

  void _openCashoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DriverCashoutSheet(
        availableBalance: _todayEarnings,
        driverId: widget.driverId,
      ),
    );
  }

  @override
  void dispose() {
    DriverDispatchListener.instance.activeOfferNotifier.removeListener(_handleOfferStateChange);
    _driverSub?.cancel();
    _tipBoostSub?.cancel();
    _countdownTimer?.cancel();
    _map?.dispose();
    DriverDispatchListener.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DriverDispatchListener.instance.updateContext(context);
    final remaining = _availableUntil?.difference(DateTime.now());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF121418),
      drawer: DriverDrawer(
        todayEarnings: _todayEarnings,
        completedTrips: _completedTrips,
        onOpenEarnings: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EarningsDashboardScreen()),
          );
        },
        onOpenHistory: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
          );
        },
        onOpenVehicleDocs: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VehicleComplianceScreen()),
          );
        },
        onOpenSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverSettingsScreen()),
          );
        },
        onEmergencyBeacon: () {},
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: GoogleMap(
                initialCameraPosition: _initialCamera,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                polygons: _online ? _surgePolygons : {},
                polylines: _online ? _activeOfferPolylines : {},
                onMapCreated: (controller) async {
                  _map = controller;
                  await controller.setMapStyle(midnightTitaniumMapStyle);
                  if (mounted) setState(() => _mapReady = true);
                },
              ),
            ),
          ),
          IgnorePointer(
            ignoring: _mapReady,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              opacity: _mapReady ? 0.0 : 1.0,
              child: Container(color: const Color(0xFF121418)),
            ),
          ),
          TacticalFlightDeck(
            isOnline: _online,
            remainingTime: _online ? remaining : null,
            todayEarnings: _todayEarnings,
            onToggleOnline: _handleStatusTap,
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            onRecenterMap: () {
              _map?.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
            },
            onOpenWallet: _openCashoutSheet,
          ),

          // 4. Persistent Tactical Demand & Surge Radar Base
          const Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: RepaintBoundary(
              child: TacticalDemandDeck(),
            ),
          ),

          // 5. In-Tree Floating Batch Offer (Floats 18px directly above Demand Deck)
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: DriverDispatchListener.instance.activeOfferNotifier,
            builder: (context, activeOffer, _) {
              if (activeOffer == null) return const SizedBox.shrink();

              return Positioned(
                left: 14,
                right: 14,
                bottom: 210, // Perfectly clears the ~192px Demand Deck + 18px air gap
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, progress, child) {
                    return Transform.translate(
                      offset: Offset(0, (1.0 - progress) * 80),
                      child: Opacity(
                        opacity: progress,
                        child: child,
                      ),
                    );
                  },
                  child: RepaintBoundary(
                    child: TransparentBatchOfferCard(
                      offer: activeOffer,
                      onPreferenceChanged: (pref) {
                        _updateOfferRoute(activeOffer, preference: pref);
                      },
                      onAccept: () async {
                        final orderId = activeOffer['orderId'];
                        await _claimAndAcceptBatch(orderId, activeOffer);
                      },
                      onDecline: () {
                        HapticFeedback.lightImpact();
                        _clearBatchOfferRoute();
                        DriverDispatchListener.instance.dismissOffer();
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // 6. In-Flight Active Order Recovery Banner
          _buildActiveOrderRecoveryBanner(),
        ],
      ),
    );
  }

  Widget _buildActiveOrderRecoveryBanner() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data() ?? {};
        final activeOrderId = data['currentOrderId'] as String?;

        if (activeOrderId == null || activeOrderId.isEmpty) return const SizedBox.shrink();

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('orders').doc(activeOrderId).get(),
          builder: (context, orderSnap) {
            if (!orderSnap.hasData || !orderSnap.data!.exists) return const SizedBox.shrink();
            final orderData = orderSnap.data!.data() ?? {};
            final status = orderData['status']?.toString() ?? '';

            if (status == 'completed' || status == 'cancelled' || status == 'cancelled_stockout') {
              return const SizedBox.shrink();
            }

            const gold = Color(0xFFE6B450);

            return Positioned(
              left: 14,
              right: 14,
              bottom: 180,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _resumeActiveOrder(activeOrderId, status, orderData),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181B22).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: gold, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delivery_dining_rounded, color: gold, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'ACTIVE RUN IN PROGRESS',
                                style: TextStyle(
                                  color: gold,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Order #$activeOrderId • Tap to resume',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: gold, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _claimAndAcceptBatch(String orderId, Map<String, dynamic> orderData) async {
    HapticFeedback.heavyImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final driverName = user?.displayName ??
          (user?.email != null && user!.email!.contains('@') ? user.email!.split('@').first : 'Thomas Davis');
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update Order Document -> Notifies Customer App Immediately!
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': 'shoppingActive',
        'driverId': widget.driverId,
        'driverName': driverName,
        'driverPhone': '+18175550198',
        'driverRating': 5.0,
        'shopperAssignedAt': FieldValue.serverTimestamp(),
      });

      // 2. Link Active Order to Driver Profile
      final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
      batch.set(driverRef, {
        'currentOrderId': orderId,
        'currentOrderStatus': 'shoppingActive',
        'activeOrderId': orderId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      // 3. Clear Offer UI and Transition to Picking
      _clearBatchOfferRoute();
      DriverDispatchListener.instance.dismissOffer();

      if (!mounted) return;
      _resumeActiveOrder(orderId, 'shoppingActive', orderData);
    } catch (e) {
      debugPrint('Error claiming batch: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim batch: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _resumeActiveOrder(String orderId, String status, Map<String, dynamic> data) {
    HapticFeedback.heavyImpact();

    if (status == 'outForDelivery') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveDeliveryScreen(
            orderId: orderId,
            customerName: (data['customerName'] ?? 'Customer').toString(),
            customerAddress: (data['customerAddress'] ?? '').toString(),
            customerLat: (data['customerLat'] as num?)?.toDouble() ?? 32.759602,
            customerLng: (data['customerLng'] as num?)?.toDouble() ?? -97.471416,
            payout: (data['guaranteedPayout'] as num?)?.toDouble() ?? 12.50,
            tipAmount: (data['customerTip'] as num?)?.toDouble() ?? 5.00,
            bagCount: (data['bagCount'] as num?)?.toInt() ?? 1,
          ),
        ),
      );
    } else {
      final itemsList = (data['items'] as List<dynamic>? ?? []).map((i) {
        final itemMap = i as Map<String, dynamic>;
        return PickItem(
          id: (itemMap['id'] ?? '').toString(),
          name: (itemMap['name'] ?? 'Item').toString(),
          aisle: (itemMap['aisle'] ?? 'General').toString(),
          imageUrl: itemMap['imageUrl']?.toString(),
          size: itemMap['size']?.toString(),
          quantity: (itemMap['quantity'] as num?)?.toInt() ?? 1,
          price: (itemMap['price'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InStorePickingScreen(
            orderId: orderId,
            storeName: (data['storeName'] ?? 'Store').toString(),
            items: itemsList,
          ),
        ),
      );
    }
  }
}
