// File: rapidrun_driver/lib/utils/external_navigation_launcher.dart

import 'package:url_launcher/url_launcher.dart';

class ExternalNavigationLauncher {
  static Future<void> launchNavigation({
    required double latitude,
    required double longitude,
    required String addressLabel,
  }) async {
    final googleMapsUrl = Uri.parse(
      'google.navigation:q=$latitude,$longitude&mode=d',
    );
    final fallbackWebUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(fallbackWebUrl)) {
      await launchUrl(fallbackWebUrl, mode: LaunchMode.externalApplication);
    }
  }
}
