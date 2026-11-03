// File: rapidrun_driver/lib/screens/driver_cockpit_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../widgets/radar/driver_availability_orb.dart';
import '../widgets/radar/surge_radar_bar.dart';
import '../widgets/map/driver_map_overlay_painter.dart';
import '../wallet/driver_cashout_sheet.dart';
import 'earnings/earnings_dashboard_screen.dart';
import 'driver_menu/trip_history_screen.dart';

class DriverCockpitScreen extends StatefulWidget {
  const DriverCockpitScreen({super.key});

  @override
  State<DriverCockpitScreen> createState() => _DriverCockpitScreenState();
}

class _DriverCockpitScreenState extends State<DriverCockpitScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DriverShiftStatus _status = DriverShiftStatus.offline;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleShift() {
    HapticFeedback.heavyImpact();
    setState(() {
      _status = _status == DriverShiftStatus.offline
          ? DriverShiftStatus.searching
          : DriverShiftStatus.offline;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _status == DriverShiftStatus.searching;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF090A0D),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // 1. Obsidian Map Canvas with Dynamic Radial Heatmap
          RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: DriverMapOverlayPainter(
                pulseAnimation: _pulseController,
                isOnline: isOnline,
              ),
            ),
          ),

          // 2. Frosted Telemetry Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171D).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        const SizedBox(width: 4.0),

                        // Animated Status Pill
                        Expanded(
                          child: GestureDetector(
                            onTap: _toggleShift,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF00E676).withValues(alpha: 0.14)
                                    : const Color(0xFFEF5350).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(
                                  color: isOnline
                                      ? const Color(0xFF00E676).withValues(alpha: 0.45)
                                      : const Color(0xFFEF5350).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isOnline ? const Color(0xFF00E676) : const Color(0xFFEF5350),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      isOnline ? 'ONLINE • HUNTING' : 'OFFLINE • TAP TO GO',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isOnline ? const Color(0xFF00E676) : Colors.white,
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),

                        // Synchronized Earnings
                        ListenableBuilder(
                          listenable: driverEarningsState,
                          builder: (context, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C2028),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Text(
                                '\$${driverEarningsState.todayEarnings.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFFE5A93C),
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6.0),

                        // Driver Availability Orb
                        DriverAvailabilityOrb(
                          initialStatus: _status,
                          onStatusChanged: (s) => setState(() => _status = s),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Persistent 1-Tap SOS Safety Shield
          Positioned(
            right: 16,
            top: 100,
            child: FloatingActionButton.small(
              heroTag: 'driver_sos_beacon',
              backgroundColor: const Color(0xFF181B22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: const Color(0xFFEF5350).withValues(alpha: 0.4), width: 1.2),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                _showEmergencyModal(context);
              },
              child: const Icon(Icons.shield_outlined, color: Color(0xFFEF5350), size: 20),
            ),
          ),

          // 4. Hardware Surge Wave Visualizer
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

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? (user?.email?.split('@').first) ?? 'Courier';

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
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                ListenableBuilder(
                  listenable: driverEarningsState,
                  builder: (context, _) {
                    final trips = driverEarningsState.completedTrips;
                    return Text(
                      'APEX FLEET · ${trips > 0 ? "5.0 ★ ($trips trips)" : "NEW DRIVER (0 trips)"}',
                      style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 11, fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: driverEarningsState,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TODAY'S PAYOUT", style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w800)),
                            Text('\$${driverEarningsState.availableCashout.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5A93C), foregroundColor: Colors.black),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const DriverCashoutSheet(),
                            );
                          },
                          child: const Text('Cash Out', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFFE5A93C)),
            title: const Text('Earnings & Cash Out', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Weekly breakdown, tips, 1099 tax', style: TextStyle(color: Colors.white38, fontSize: 11)),
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => const EarningsDashboardScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.route_outlined, color: Colors.white70),
            title: const Text('Trip History', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Past runs, itemized lists, route audits', style: TextStyle(color: Colors.white38, fontSize: 11)),
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => const TripHistoryScreen()));
            },
          ),
        ],
      ),
    );
  }

  void _showEmergencyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16181F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 48),
            const SizedBox(height: 12),
            const Text('RapidRun Safety & Emergency', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Share your live GPS telemetry with dispatch or connect directly with 911 services.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350), foregroundColor: Colors.white),
                icon: const Icon(Icons.phone_in_talk_rounded),
                label: const Text('CALL 911 EMERGENCY', style: TextStyle(fontWeight: FontWeight.w900)),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
