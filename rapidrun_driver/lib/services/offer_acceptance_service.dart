import 'package:cloud_firestore/cloud_firestore.dart';
import '../presentation/home/incoming_offer_overlay.dart';

/// Service responsible for persisting accepted/declined offers (Option A strategy).
class OfferAcceptanceService {
  OfferAcceptanceService._();
  static final instance = OfferAcceptanceService._();

  final _orders = FirebaseFirestore.instance.collection('orders');
  final _drivers = FirebaseFirestore.instance.collection('drivers');
  final _events = FirebaseFirestore.instance.collection('driver_events');

  /// Accepts an offer by writing/merging an order doc and updating driver pointer.
  Future<void> acceptOffer({
    required String driverId,
    required IncomingOfferData offer,
  }) async {
    final orderRef = _orders.doc(offer.id);
    final driverRef = _drivers.doc(driverId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      if (orderSnap.exists) {
        final existingDriver = orderSnap.data()?['driverId'];
        if (existingDriver != null && existingDriver != driverId) {
          // Already claimed by someone else; abort.
          throw StateError('Order already claimed');
        }
      }
      tx.set(orderRef, {
        'status': 'assigned',
        'createdAt': FieldValue.serverTimestamp(),
        'assignedAt': FieldValue.serverTimestamp(),
        'driverId': driverId,
        'storeName': offer.store,
        'dropoffArea': offer.dropoffArea,
        'pay': offer.pay,
        'distanceMiles': offer.distanceMiles,
        'etaMinutes': offer.eta.inMinutes,
        'source': 'mock_local',
      }, SetOptions(merge: true));
      tx.set(driverRef, {'activeOrderId': offer.id}, SetOptions(merge: true));
      // Basic telemetry event (fire-and-forget inside txn context ok as separate doc not read dependent)
      final evtRef = _events.doc();
      tx.set(evtRef, {
        'type': 'offer_accept',
        'driverId': driverId,
        'offerId': offer.id,
        'pay': offer.pay,
        'ts': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Records a decline (optional minimal implementation). For now noop; placeholder for analytics.
  Future<void> declineOffer({
    required String driverId,
    required IncomingOfferData offer,
  }) async {
    // Maintain a bounded recentDeclines array (max 25) + telemetry event.
    final driverRef = _drivers.doc(driverId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(driverRef);
      List declines = [];
      if (snap.exists) {
        final data = snap.data();
        if (data != null && data['recentDeclines'] is List) {
          declines = List.from(data['recentDeclines']);
        }
      }
      declines.insert(0, offer.id);
      if (declines.length > 25) declines = declines.sublist(0, 25);
      tx.set(driverRef, {'recentDeclines': declines}, SetOptions(merge: true));
      final evtRef = _events.doc();
      tx.set(evtRef, {
        'type': 'offer_decline',
        'driverId': driverId,
        'offerId': offer.id,
        'pay': offer.pay,
        'ts': FieldValue.serverTimestamp(),
      });
    });
  }
}
