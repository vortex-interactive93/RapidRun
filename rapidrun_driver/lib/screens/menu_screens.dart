import 'package:flutter/material.dart';

// Simple placeholder scaffolds for drawer destinations. Later these can be
// replaced with real feature implementations without changing navigation.

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen(this.title);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title Coming Soon',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class TripsScreen extends _PlaceholderScreen {
  const TripsScreen() : super('Trips');
}

class EarningsScreen extends _PlaceholderScreen {
  const EarningsScreen() : super('Earnings');
}

class NotificationsScreen extends _PlaceholderScreen {
  const NotificationsScreen() : super('Notifications');
}

class DriverLicenseScreen extends _PlaceholderScreen {
  const DriverLicenseScreen() : super('Driver License');
}

class VehiclesScreen extends _PlaceholderScreen {
  const VehiclesScreen() : super('Vehicles');
}

class AccountScreen extends _PlaceholderScreen {
  const AccountScreen() : super('Account');
}

class MyMetricsScreen extends _PlaceholderScreen {
  const MyMetricsScreen() : super('My Metrics');
}

class IncentiveProgramsScreen extends _PlaceholderScreen {
  const IncentiveProgramsScreen() : super('Incentive Programs');
}

class ReferEarnScreen extends _PlaceholderScreen {
  const ReferEarnScreen() : super('Refer & Earn');
}

class CertificationsScreen extends _PlaceholderScreen {
  const CertificationsScreen() : super('Certifications');
}

class HelpScreen extends _PlaceholderScreen {
  const HelpScreen() : super('Help');
}

class ResourceCenterScreen extends _PlaceholderScreen {
  const ResourceCenterScreen() : super('Resource Center');
}

class SettingsScreen extends _PlaceholderScreen {
  const SettingsScreen() : super('Settings');
}
