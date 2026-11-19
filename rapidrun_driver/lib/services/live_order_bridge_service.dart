// File: rapidrun_driver/lib/services/live_order_bridge_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared Firestore order lifecycle connecting Customer Checkout -> Driver Fulfillment.
/// Statuses: 'pending' -> 'shopping' -> 'in_transit' -> 'delivered'
class LiveOrderBridgeService {
  final FirebaseFirestore _firestore;

  LiveOrderBridgeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _firestore.collection('orders');

  /// Driver screen listens for newly placed customer orders ('pending')
  Stream<List<Map<String, dynamic>>> watchPendingOrders() {
    return _ordersCol
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final map = Map<String, dynamic>.from(doc.data());
              map['orderId'] = doc.id;
              return map;
            }).toList());
  }

  /// Driver atomically claims the order so no duplicate acceptance occurs
  Future<bool> acceptOrder({
    required String orderId,
    required String driverId,
    required String driverName,
  }) async {
    final ref = _ordersCol.doc(orderId);
    return _firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final current = snap.data()!;
      if (current['status'] != 'pending') return false;

      tx.update(ref, {
        'status': 'shopping',
        'driverId': driverId,
        'driverName': driverName,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  /// Driver marks items picked -> customer sees live picking count & shopper status
  Future<void> updatePickedItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
  }) async {
    final pickedCount = items.where((i) => i['isPicked'] == true).length;
    await _ordersCol.doc(orderId).update({
      'items': items,
      'pickedCount': pickedCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Driver advances through 'in_transit' and 'delivered'
  Future<void> setOrderStatus({
    required String orderId,
    required String status,
    int? bagsPacked,
    String? dropoffPhotoUrl,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (bagsPacked != null) updates['bagsPacked'] = bagsPacked;
    if (dropoffPhotoUrl != null) updates['dropoffPhotoUrl'] = dropoffPhotoUrl;
    if (status == 'in_transit') updates['startedDeliveryAt'] = FieldValue.serverTimestamp();
    if (status == 'delivered') updates['deliveredAt'] = FieldValue.serverTimestamp();

    await _ordersCol.doc(orderId).update(updates);
  }
}
