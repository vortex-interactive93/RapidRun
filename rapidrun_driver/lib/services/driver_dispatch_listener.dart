// File: rapidrun_driver/lib/services/driver_dispatch_listener.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DriverDispatchListener {
  DriverDispatchListener._internal();
  static final DriverDispatchListener instance = DriverDispatchListener._internal();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;

  /// Reactive stream for in-tree offer overlay (no modal route)
  final ValueNotifier<Map<String, dynamic>?> activeOfferNotifier = ValueNotifier(null);

  void initializeAutoDispatch(BuildContext context) {
    _ordersSub?.cancel();

    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
      final unassignedDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final s = (data['status'] ?? '').toString();
        final dId = data['driverId'];
        return (s == 'pendingDispatch' || s == 'pending_dispatch') &&
            (dId == null || dId == '');
      }).toList();

      if (unassignedDocs.isNotEmpty) {
        final doc = unassignedDocs.first;
        final data = Map<String, dynamic>.from(doc.data());
        data['orderId'] = doc.id;
        activeOfferNotifier.value = data;
      } else {
        activeOfferNotifier.value = null;
      }
    });
  }

  void updateContext(BuildContext context) {}

  void resetActiveState() {
    activeOfferNotifier.value = null;
  }

  void dismissOffer() {
    activeOfferNotifier.value = null;
  }

  void dispose() {
    _ordersSub?.cancel();
    activeOfferNotifier.value = null;
  }
}
