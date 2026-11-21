// File: rapidrun_driver/lib/screens/shell/driver_drawer.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/unified_driver_wallet_controller.dart';
import '../earnings/earnings_dashboard_screen.dart';
import '../driver_menu/trip_history_screen.dart';
import '../driver_menu/vehicle_compliance_screen.dart';
import '../driver_menu/driver_settings_screen.dart';
import '../wallet/driver_cashout_sheet.dart';

class DriverDrawer extends StatelessWidget {
  final String? driverName;
  final double? todayEarnings;
  final int? completedTrips;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenVehicleDocs;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onEmergencyBeacon;

  const DriverDrawer({
    super.key,
    this.driverName,
    this.todayEarnings,
    this.completedTrips,
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
    final displayName = driverName ??
        user?.displayName ??
        (user?.email?.split('@').first) ??
        'Thomas';

    // Listen to UnifiedDriverWalletController so Drawer balances always stay
    // locked in sync with Earnings & Payouts and Cash Out actions.
    return ListenableBuilder(
      listenable: UnifiedDriverWalletController.instance,
      builder: (context, _) {
        final wallet = UnifiedDriverWalletController.instance;

        // If todayEarnings was explicitly passed and wallet hasn't recorded activity yet,
        // use wallet.availableCashout once active so cash-out zeroes the drawer payout cleanly.
        final double drawerPayout = wallet.completedTrips > 0 || wallet.totalCashedOut > 0
            ? wallet.availableCashout
            : (todayEarnings ?? wallet.availableCashout);
        final int activeTrips = completedTrips ?? wallet.completedTrips;

        return RepaintBoundary(
          child: Drawer(
            backgroundColor: bg,
            elevation: 16,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                children: [
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
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: gold.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'APEX FLEET',
                                          style: TextStyle(
                                            color: gold,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '★ 5.0 ($activeTrips trips)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: Curves.fastOutSlowIn,
                                    switchOutCurve: Curves.fastOutSlowIn,
                                    child: Text(
                                      '\$${drawerPayout.toStringAsFixed(2)}',
                                      key: ValueKey<String>(drawerPayout.toStringAsFixed(2)),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: drawerPayout > 0 ? gold : const Color(0xFF2A2E37),
                                  foregroundColor: drawerPayout > 0 ? Colors.black : Colors.white54,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const DriverCashoutSheet(),
                                  );
                                },
                                child: const Text(
                                  'Cash Out',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _DrawerTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Earnings & Cash Out',
                          subtitle: 'Weekly breakdown, tips, 1099 tax logs',
                          onTap: () {
                            Navigator.pop(context);
                            if (onOpenEarnings != null) {
                              onOpenEarnings!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EarningsDashboardScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        _DrawerTile(
                          icon: Icons.history_rounded,
                          title: 'Trip History',
                          subtitle: 'Past runs, itemized lists, route audits',
                          onTap: () {
                            Navigator.pop(context);
                            if (onOpenHistory != null) {
                              onOpenHistory!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TripHistoryScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        _DrawerTile(
                          icon: Icons.local_shipping_outlined,
                          title: 'Vehicle & Compliance',
                          subtitle: 'Insurance active, cold bag verified',
                          onTap: () {
                            Navigator.pop(context);
                            if (onOpenVehicleDocs != null) {
                              onOpenVehicleDocs!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VehicleComplianceScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        _DrawerTile(
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
                                MaterialPageRoute(
                                  builder: (_) => const DriverSettingsScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE6B450), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
