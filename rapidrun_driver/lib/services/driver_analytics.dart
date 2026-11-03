import 'package:firebase_analytics/firebase_analytics.dart';

/// Lightweight wrapper to keep event names consistent and provide a safe call site.
class DriverAnalytics {
  DriverAnalytics._();
  static final instance = DriverAnalytics._();
  final _fa = FirebaseAnalytics.instance;

  Future<void> log(String name, Map<String, Object> params) async {
    try {
      final send = Map<String, Object>.from(params);
      await _fa.logEvent(name: name, parameters: send);
    } catch (_) {
      // swallow – analytics must never crash user flow
    }
  }

  Future<void> offerEnqueue({
    required String offerId,
    required double pay,
    required int queueLen,
  }) => log('offer_enqueue', {
    'offer_id': offerId,
    'pay': pay,
    'queue_len': queueLen,
  });
  Future<void> offerCinematicShow(String offerId) =>
      log('offer_cinematic_show', {'offer_id': offerId});
  Future<void> offerAccept(String offerId, double pay) =>
      log('offer_accept_tap', {'offer_id': offerId, 'pay': pay});
  Future<void> offerDecline(String offerId, double pay) =>
      log('offer_decline_tap', {'offer_id': offerId, 'pay': pay});
  Future<void> offerCycle(String newOfferId, int index, int total) => log(
    'offer_cycle',
    {'offer_id': newOfferId, 'index': index, 'total': total},
  );
  Future<void> postDeliveryToast() => log('post_delivery_toast', {});
}
