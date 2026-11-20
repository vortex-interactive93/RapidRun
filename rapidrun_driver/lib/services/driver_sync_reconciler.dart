// File: rapidrun_driver/lib/services/driver_sync_reconciler.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Reconciles live order queries (without requiring composite Firestore indexes)
/// and keeps driver balance, earnings, and tip boost fields in sync.
class DriverSyncReconciler {
  final FirebaseFirestore _firestore;

  DriverSyncReconciler({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Streams pending orders safely without triggering composite-index errors
  Stream<List<Map<String, dynamic>>> streamPendingOrdersSafe() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['orderId'] = doc.id;
        return data;
      }).toList();

      list.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
        final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
        return bMs.compareTo(aMs);
      });

      return list;
    });
  }

  /// Credits a newly arrived post-delivery tip boost delta to the driver doc
  /// and increments available cashout/balance by the exact incremental amount.
  Future<void> applyIncrementalTipBoost({
    required String driverId,
    required String orderId,
    required double incrementalBoost,
  }) async {
    if (incrementalBoost <= 0) return;

    final roundedBoost = double.parse(incrementalBoost.toStringAsFixed(2));
    final orderRef = _firestore.collection('orders').doc(orderId);
    final driverRef = _firestore.collection('drivers').doc(driverId);

    try {
      await orderRef.set({
        'tipBoostPending': false,
        'pendingBoostAmount': FieldValue.delete(),
        'tipBoostAppliedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await driverRef.set({
        'todayEarnings': FieldValue.increment(roundedBoost),
        'balance': FieldValue.increment(roundedBoost),
        'availableCashout': FieldValue.increment(roundedBoost),
        'customerTips': FieldValue.increment(roundedBoost),
        'boostedTips': FieldValue.increment(roundedBoost),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Tip boost reconcile warning: $e');
    }
  }
}
