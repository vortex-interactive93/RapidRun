// File: rapidrun_driver/lib/services/navigation_launcher_service.dart

import 'package:url_launcher/url_launcher.dart';

class NavigationLauncherService {
  /// Launches turn-by-turn navigation via external apps without SDK costs or API keys
  static Future<void> launchNavigation({
    required double destinationLat,
    required double destinationLng,
    required String destinationLabel,
    String provider = 'google', // 'google', 'waze', or 'native'
  }) async {
    if (provider == 'waze') {
      final wazeUri = Uri.parse(
        'waze://?ll=$destinationLat,$destinationLng&navigate=yes',
      );
      final fallbackWazeUri = Uri.parse(
        'https://waze.com/ul?ll=$destinationLat,$destinationLng&navigate=yes',
      );

      if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallbackWazeUri, mode: LaunchMode.externalApplication);
      }
    } else {
      // Default: Native Android Google Navigation Turn-by-Turn Intent
      final googleUri = Uri.parse(
        'google.navigation:q=$destinationLat,$destinationLng&mode=d',
      );
      final fallbackUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng',
      );

      if (await canLaunchUrl(googleUri)) {
        await launchUrl(googleUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
