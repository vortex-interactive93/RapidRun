import 'dart:developer' as dev;

/// Minimal analytics stub; can be swapped with Firebase/Segment later.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  Future<void> log(
    String event, {
    Map<String, Object?> props = const {},
  }) async {
    dev.log(
      '[analytics] $event ${props.isEmpty ? '' : props}',
      name: 'analytics',
    );
  }
}
