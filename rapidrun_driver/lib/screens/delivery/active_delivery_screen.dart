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
import '../../presentation/home/map_styles/midnight_titanium.dart';
import '../../widgets/navigation/turn_by_turn_hud_banner.dart';

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
  });

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  bool _arrivedAtCustomer = false;
  bool _dropoffPhotoTaken = false;
  bool _isCompleting = false;
  bool _mapReady = false;

  late final LatLng _customerLoc;

  @override
  void initState() {
    super.initState();
    _customerLoc = LatLng(widget.customerLat, widget.customerLng);
    _startLiveTelemetryEmitter();
  }

  void _startLiveTelemetryEmitter() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) {
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
          'driverLat': position.latitude,
          'driverLng': position.longitude,
          'driverHeading': position.heading,
          'driverLocation': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'lastTelemetryAt': FieldValue.serverTimestamp(),
        }).catchError((e) {
          debugPrint('Telemetry sync warning: $e');
        });
      },
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _launchExternalNav() async {
    HapticFeedback.lightImpact();

    // Uses exact lat/long coordinates with driving mode
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

  Future<void> _smsCustomer() async {
    _openChatSheet();
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
    setState(() => _isCompleting = true);
    HapticFeedback.heavyImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();

      // 1. Mark order completed
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      batch.update(orderRef, {
        'status': 'completed',
        'dropoffPhotoUrl': 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=600&q=80',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      // 2. Atomically update driver document fields allowed by Firestore rules
      if (user != null) {
        final driverRef = FirebaseFirestore.instance.collection('drivers').doc(user.uid);
        batch.set(driverRef, {
          'currentOrderId': FieldValue.delete(),
          'currentOrderStatus': FieldValue.delete(),
          'activeOrderId': FieldValue.delete(),
          'todayEarnings': FieldValue.increment(widget.payout),
          'totalDeliveriesCompleted': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Commit the batch safely without unpermitted sub-collections
      await batch.commit();

      // 3. Immediately update shared local state for instant ledger reflection
      driverEarningsState.recordCompletedBatch(
        payoutAmount: widget.payout,
        tip: widget.tipAmount,
      );

      if (!mounted) return;

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing delivery: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const bg = Color(0xFF141414);
    const cardSurface = Color(0xFF1C1C1C);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 1. Live Vector Map with Exact Rooftop Target Location
          Positioned.fill(
            child: RepaintBoundary(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _customerLoc,
                  zoom: 16.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (c) async {
                  _mapController = c;
                  await c.setMapStyle(midnightTitaniumMapStyle);
                  c.animateCamera(CameraUpdate.newLatLngZoom(_customerLoc, 16.0));
                  if (mounted) setState(() => _mapReady = true);
                },
                markers: {
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
              ),
            ),
          ),

          // Anti-Flash Obsidian Veil
          IgnorePointer(
            ignoring: _mapReady,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              opacity: _mapReady ? 0.0 : 1.0,
              child: Container(color: const Color(0xFF141414)),
            ),
          ),

          // 2. Top Turn-by-Turn Navigation HUD Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: const TurnByTurnHudBanner(
              instruction: 'Turn right on White Settlement Rd',
              distanceRemaining: '450 ft',
              maneuverIcon: Icons.turn_right_rounded,
            ),
          ),

          // 3. Bottom Customer Briefing Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.customerName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                            const SizedBox(height: 2),
                            Text(
                              widget.customerAddress,
                              style: const TextStyle(color: Colors.white54, fontSize: 12.5),
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
                            icon: const Icon(Icons.phone_rounded, size: 20),
                            onPressed: _callCustomer,
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: gold,
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                            onPressed: _smsCustomer,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
                    builder: (context, snapshot) {
                      final liveNotes = snapshot.data?.data()?['deliveryNotes'] ?? widget.deliveryNotes;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.doorbell_outlined, color: Color(0xFFE6B450), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                liveNotes,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  if (!_arrivedAtCustomer) ...[
                    SizedBox(
                      height: 52,
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
                        icon: const Icon(Icons.location_on_rounded, color: Colors.black),
                        label: const Text(
                          'ARRIVED AT CUSTOMER',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _dropoffPhotoTaken ? Colors.greenAccent : gold,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _simulatePhotoCapture,
                              icon: Icon(
                                _dropoffPhotoTaken ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                                color: _dropoffPhotoTaken ? Colors.greenAccent : gold,
                              ),
                              label: Text(
                                _dropoffPhotoTaken ? 'Photo Taken' : 'Snap Photo',
                                style: TextStyle(
                                  color: _dropoffPhotoTaken ? Colors.greenAccent : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
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
                                        fontSize: 14,
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
    final basePay = totalPayout - tip;

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
