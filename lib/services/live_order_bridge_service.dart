// File: lib/services/live_order_bridge_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared Firestore order lifecycle connecting Customer Checkout -> Driver Fulfillment.
/// Statuses: 'pending' -> 'shopping' -> 'in_transit' -> 'delivered'
class LiveOrderBridgeService {
  final FirebaseFirestore _firestore;

  LiveOrderBridgeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _firestore.collection('orders');

  /// Called when the customer taps "PLACE ORDER" in Checkout
  Future<String> createLiveOrder({
    required String customerId,
    required String customerName,
    required String deliveryAddress,
    required String deliveryNotes,
    required String storeId,
    required String storeName,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double deliveryFee,
    required double serviceFee,
    required double tax,
    required double tip,
  }) async {
    final total = subtotal + deliveryFee + serviceFee + tax + tip;
    final driverPayout = (deliveryFee > 0 ? deliveryFee : 6.50) + 4.18;

    final preparedItems = cartItems.map((item) {
      return {
        ...item,
        'isPicked': false,
        'isMissing': false,
      };
    }).toList();

    final docRef = await _ordersCol.add({
      'customerId': customerId,
      'customerName': customerName,
      'deliveryAddress': deliveryAddress,
      'deliveryNotes': deliveryNotes,
      'storeId': storeId,
      'storeName': storeName,
      'items': preparedItems,
      'itemCount': preparedItems.fold<int>(
        0,
        (sum, i) => sum + ((i['quantity'] as num?)?.toInt() ?? 1),
      ),
      'pickedCount': 0,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'serviceFee': serviceFee,
      'tax': tax,
      'tip': tip,
      'total': double.parse(total.toStringAsFixed(2)),
      'driverPayout': double.parse(driverPayout.toStringAsFixed(2)),
      'guaranteedPayout': double.parse((driverPayout + tip).toStringAsFixed(2)),
      'customerTip': tip,
      'status': 'pending',
      'driverId': null,
      'driverName': null,
      'bagsPacked': 1,
      'dropoffPhotoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Customer screen listens to live status, shopper assignment, picking & dropoff
  Stream<Map<String, dynamic>?> watchOrder(String orderId) {
    return _ordersCol.doc(orderId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final map = Map<String, dynamic>.from(snap.data()!);
      map['orderId'] = snap.id;
      return map;
    });
  }

  /// Driver screen listens for newly placed customer orders ('pending')
  Stream<List<Map<String, dynamic>>> watchPendingOrders() {
    return _ordersCol
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) {
        final map = Map<String, dynamic>.from(doc.data());
        map['orderId'] = doc.id;
        return map;
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
