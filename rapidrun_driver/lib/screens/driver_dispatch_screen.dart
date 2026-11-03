// File: rapidrun_driver/lib/screens/driver_dispatch_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/radar/driver_availability_orb.dart';
import '../widgets/radar/surge_radar_bar.dart';
import '../widgets/order/slide_to_accept_order.dart';

class DriverDispatchScreen extends StatefulWidget {
  const DriverDispatchScreen({super.key});

  @override
  State<DriverDispatchScreen> createState() => _DriverDispatchScreenState();
}

class _DriverDispatchScreenState extends State<DriverDispatchScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DriverShiftStatus _status = DriverShiftStatus.searching;
  int _countdownSeconds = 30;
  Timer? _countdownTimer;
  bool _hasActiveOffer = true;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = 30;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        if (mounted) setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _hasActiveOffer = false);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _status == DriverShiftStatus.searching;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0C0C0E),
      drawer: _buildDriverNavigationDrawer(),
      body: Stack(
        children: [
          // 1. High-Contrast Obsidian Map Canvas
          Container(
            color: const Color(0xFF090A0D),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.navigation_rounded,
                    size: 96,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                // Glowing Route Trajectory Simulation
                if (_hasActiveOffer)
                  CustomPaint(
                    size: Size.infinite,
                    painter: _GlowingRoutePainter(),
                  ),
              ],
            ),
          ),

          // 2. High-Velocity Telemetry Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Navigation Drawer Trigger
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF14171D).withValues(alpha: 0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),

                  // Shift Duration Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171D).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFF00E676) : const Color(0xFFE5A93C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? 'ONLINE · 1h 58m' : 'STANDBY',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Shift Earnings Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171D).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Text(
                      '\$483.08',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Driver Availability Orb
                  DriverAvailabilityOrb(
                    initialStatus: _status,
                    onStatusChanged: (newStatus) {
                      setState(() => _status = newStatus);
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Batch Offer HUD
          if (_hasActiveOffer)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171D).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1E26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: Color(0xFFE5A93C),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bath & Body Works',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '\$16.58 · 2 SKUs (3 total units)',
                                  style: TextStyle(
                                    color: Color(0xFFE5A93C),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Circular Expiry Indicator
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _countdownSeconds <= 7
                                    ? const Color(0xFFEF5350)
                                    : const Color(0xFFE5A93C),
                                width: 2.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$_countdownSeconds',
                                style: TextStyle(
                                  color: _countdownSeconds <= 7
                                      ? const Color(0xFFEF5350)
                                      : const Color(0xFFE5A93C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SlideToAcceptOrder(
                        label: 'SLIDE TO ACCEPT BATCH',
                        onAccepted: () async {
                          HapticFeedback.heavyImpact();
                          _countdownTimer?.cancel();
                          setState(() => _hasActiveOffer = false);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. RepaintBoundary-Isolated Demand & Surge Radar
          const Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SurgeRadarVisualizer(
              surgeMultiplier: 2.50,
              activeZone: 'Westover Village',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverNavigationDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F1115),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF14171D)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.black, size: 30),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thomas Davis',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const Text(
                  'Verified Noir Courier · 5.0 ★',
                  style: TextStyle(color: Color(0xFFE5A93C), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.credit_card_rounded, color: Color(0xFFE5A93C)),
            title: const Text('RapidRun Fleet Card', style: TextStyle(color: Colors.white)),
            subtitle: const Text('MasterCard ···· 0021 (JIT Active)', style: TextStyle(color: Colors.white38, fontSize: 11)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
            title: const Text('Instant Stripe Cashout', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.navigation_outlined, color: Colors.white70),
            title: const Text('GPS & Turn-by-Turn App', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Google Maps / Waze', style: TextStyle(color: Colors.white38, fontSize: 11)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded, color: Colors.white70),
            title: const Text('Shopping Preferences', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _GlowingRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.72, size.height * 0.44)
      ..lineTo(size.width * 0.48, size.height * 0.38)
      ..lineTo(size.width * 0.48, size.height * 0.28)
      ..lineTo(size.width * 0.62, size.height * 0.25);

    // Ambient glow
    final glowPaint = Paint()
      ..color = const Color(0xFFE5A93C).withValues(alpha: 0.35)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawPath(path, glowPaint);

    // Crisp hardware core line
    final corePaint = Paint()
      ..color = const Color(0xFFE5A93C)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
