import 'package:flutter/material.dart';
import '../screens/driver_home_screen.dart';
import '../screens/active_order_screen.dart';
import '../screens/available_orders_screen.dart';
// Drawer placeholder imports
import '../screens/menu_screens.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

/// Central route names.
class AppRoutes {
  static const home = '/';
  static const activeOrder = '/active-order';
  static const availableOrders = '/available-orders';
  // Drawer / profile style sections
  static const trips = '/trips';
  static const earnings = '/earnings';
  static const notifications = '/notifications';
  static const driverLicense = '/driver-license';
  static const vehicles = '/vehicles';
  static const account = '/account';
  static const myMetrics = '/my-metrics';
  static const incentivePrograms = '/incentive-programs';
  static const referEarn = '/refer-earn';
  static const certifications = '/certifications';
  static const help = '/help';
  static const resourceCenter = '/resource-center';
  static const settings = '/settings';
}

/// Route generator centralizing page construction & enabling future analytics.
Route<dynamic>? onGenerateRoute(
  RouteSettings settings, {
  required String driverId,
  Order? activeOrder,
  VoidCallback? onSignOut,
}) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(
        builder: (_) => DriverHomeScreen(driverId: driverId),
      );
    case AppRoutes.activeOrder:
      if (activeOrder == null) return _error('No active order provided');
      return MaterialPageRoute(
        builder: (_) =>
            ActiveOrderScreen(order: activeOrder, onSignOut: onSignOut),
      );
    case AppRoutes.availableOrders:
      return MaterialPageRoute(builder: (_) => const AvailableOrdersScreen());
    case AppRoutes.trips:
      return MaterialPageRoute(builder: (_) => const TripsScreen());
    case AppRoutes.earnings:
      return MaterialPageRoute(builder: (_) => const EarningsScreen());
    case AppRoutes.notifications:
      return MaterialPageRoute(builder: (_) => const NotificationsScreen());
    case AppRoutes.driverLicense:
      return MaterialPageRoute(builder: (_) => const DriverLicenseScreen());
    case AppRoutes.vehicles:
      return MaterialPageRoute(builder: (_) => const VehiclesScreen());
    case AppRoutes.account:
      return MaterialPageRoute(builder: (_) => const AccountScreen());
    case AppRoutes.myMetrics:
      return MaterialPageRoute(builder: (_) => const MyMetricsScreen());
    case AppRoutes.incentivePrograms:
      return MaterialPageRoute(builder: (_) => const IncentiveProgramsScreen());
    case AppRoutes.referEarn:
      return MaterialPageRoute(builder: (_) => const ReferEarnScreen());
    case AppRoutes.certifications:
      return MaterialPageRoute(builder: (_) => const CertificationsScreen());
    case AppRoutes.help:
      return MaterialPageRoute(builder: (_) => const HelpScreen());
    case AppRoutes.resourceCenter:
      return MaterialPageRoute(builder: (_) => const ResourceCenterScreen());
    case AppRoutes.settings:
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
  }
  return _error('Unknown route: ${settings.name}');
}

Route<dynamic> _error(String msg) => MaterialPageRoute(
  builder: (_) => Scaffold(
    appBar: AppBar(title: const Text('Navigation Error')),
    body: Center(child: Text(msg)),
  ),
);
