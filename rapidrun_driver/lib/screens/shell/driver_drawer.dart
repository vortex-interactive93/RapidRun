// File: rapidrun_driver/lib/screens/shell/driver_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../earnings/earnings_dashboard_screen.dart';
import '../driver_menu/trip_history_screen.dart';
import '../driver_menu/vehicle_compliance_screen.dart';
import '../driver_menu/driver_settings_screen.dart';
import '../wallet/driver_cashout_sheet.dart';

class DriverDrawer extends StatelessWidget {
  final String? driverName;
  final String driverTier;
  final double rating;
  final int? completedTrips;
  final double? todayEarnings;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenVehicleDocs;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onEmergencyBeacon;

  const DriverDrawer({
    super.key,
    this.driverName,
    this.driverTier = 'Apex Fleet',
    this.rating = 5.0,
    this.completedTrips,
    this.todayEarnings,
    this.onOpenEarnings,
    this.onOpenHistory,
    this.onOpenVehicleDocs,
    this.onOpenSettings,
    this.onEmergencyBeacon,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const bg = Color(0xFF141414);
    const cardSurface = Color(0xFF1E1E1E);

    final user = FirebaseAuth.instance.currentUser;
    final displayName = driverName ?? user?.displayName ?? (user?.email?.split('@').first) ?? 'Courier';

    return ListenableBuilder(
      listenable: driverEarningsState,
      builder: (context, _) {
        final activeEarnings = todayEarnings ?? driverEarningsState.availableCashout;
        final activeTrips = completedTrips ?? driverEarningsState.completedTrips;

        return Drawer(
          backgroundColor: bg,
          elevation: 16,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. Driver Identity & Metric Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: gold, width: 1.5),
                              color: cardSurface,
                            ),
                            child: const Icon(Icons.person, color: gold, size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: gold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        driverTier.toUpperCase(),
                                        style: const TextStyle(
                                          color: gold,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.star_rounded, color: gold, size: 14),
                                    const SizedBox(width: 2),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '($activeTrips trips)',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Today's Live Earnings Strip
                      InkWell(
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop();
                          if (onOpenEarnings != null) {
                            onOpenEarnings!();
                          } else {
                            nav.push(
                              MaterialPageRoute(builder: (_) => const EarningsDashboardScreen()),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: gold.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "TODAY'S PAYOUT",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '\$${activeEarnings.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const DriverCashoutSheet(),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: gold,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Cash Out',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
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
                ),

                // 2. Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildDrawerItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Earnings & Cash Out',
                        subtitle: 'Weekly breakdown, tips, 1099 tax logs',
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop();
                          if (onOpenEarnings != null) {
                            onOpenEarnings!();
                          } else {
                            nav.push(
                              MaterialPageRoute(builder: (_) => const EarningsDashboardScreen()),
                            );
                          }
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.history_rounded,
                        title: 'Trip History',
                        subtitle: 'Past runs, itemized lists, route audits',
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop();
                          if (onOpenHistory != null) {
                            onOpenHistory!();
                          } else {
                            nav.push(
                              MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
                            );
                          }
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.tune_rounded,
                        title: 'Dispatch & Store Filters',
                        subtitle: 'Target radius, heavy batches, store gating',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.verified_user_outlined,
                        title: 'Vehicle & Compliance',
                        subtitle: 'Insurance active, cold bag verified',
                        onTap: () {
                          Navigator.pop(context);
                          if (onOpenVehicleDocs != null) {
                            onOpenVehicleDocs!();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const VehicleComplianceScreen()),
                            );
                          }
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.near_me_outlined,
                        title: 'Navigation App Preferences',
                        subtitle: 'In-app turn-by-turn, Google Maps, Waze',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.settings_outlined,
                        title: 'App Settings & Audio Alerts',
                        subtitle: 'Order chimes, haptics, battery optimization',
                        onTap: () {
                          Navigator.pop(context);
                          if (onOpenSettings != null) {
                            onOpenSettings!();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DriverSettingsScreen()),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 3. Emergency SOS Anchor
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (onEmergencyBeacon != null) {
                        onEmergencyBeacon!();
                      }
                    },
                    icon: const Icon(Icons.shield_outlined, size: 20),
                    label: const Text(
                      'RapidRun Safety & 911 Beacon',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFE6B450);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: gold, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
      onTap: onTap,
    );
  }
}
