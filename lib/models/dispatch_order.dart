// File: lib/models/dispatch_order.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pendingDispatch,
  driverAssigned,
  shoppingActive,
  registerCheckout,
  outForDelivery,
  completed,
  cancelled,
}

class DispatchOrder {
  final String id;
  final String customerId;
  final String customerName;
  final String customerAddress;
  final double customerLat;
  final double customerLng;
  final String storeId;
  final String storeName;
  final String storeAddress;
  final double storeLat;
  final double storeLng;
  final double subtotal;
  final double guaranteedPayout;
  final double customerTip;
  final double deliveryFee;
  final double totalMiles;
  final int itemCount;
  final List<Map<String, dynamic>> items;
  final OrderStatus status;
  final String? driverId;
  final double? driverLat;
  final double? driverLng;
  final double? driverHeading;
  final DateTime createdAt;
  final bool isHeavy;
  final double estimatedWeightLbs;

  const DispatchOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.customerLat,
    required this.customerLng,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    required this.storeLat,
    required this.storeLng,
    required this.subtotal,
    required this.guaranteedPayout,
    required this.customerTip,
    required this.deliveryFee,
    required this.totalMiles,
    required this.itemCount,
    required this.items,
    required this.status,
    this.driverId,
    this.driverLat,
    this.driverLng,
    this.driverHeading,
    required this.createdAt,
    this.isHeavy = false,
    this.estimatedWeightLbs = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'storeId': storeId,
      'storeName': storeName,
      'storeAddress': storeAddress,
      'storeLat': storeLat,
      'storeLng': storeLng,
      'subtotal': subtotal,
      'guaranteedPayout': guaranteedPayout,
      'customerTip': customerTip,
      'deliveryFee': deliveryFee,
      'totalMiles': totalMiles,
      'itemCount': itemCount,
      'items': items,
      'status': status.name,
      'driverId': driverId,
      'driverLat': driverLat,
      'driverLng': driverLng,
      'driverHeading': driverHeading,
      'createdAt': Timestamp.fromDate(createdAt),
      'isHeavy': isHeavy,
      'estimatedWeightLbs': estimatedWeightLbs,
    };
  }

  factory DispatchOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DispatchOrder(
      id: doc.id,
      customerId: (data['customerId'] ?? '').toString(),
      customerName: (data['customerName'] ?? 'RapidRun Customer').toString(),
      customerAddress: (data['customerAddress'] ?? '').toString(),
      customerLat: (data['customerLat'] as num?)?.toDouble() ?? 32.759602,
      customerLng: (data['customerLng'] as num?)?.toDouble() ?? -97.471416,
      storeId: (data['storeId'] ?? 'store_default').toString(),
      storeName: (data['storeName'] ?? 'Partner Store').toString(),
      storeAddress: (data['storeAddress'] ?? '').toString(),
      storeLat: (data['storeLat'] as num?)?.toDouble() ?? 32.7485,
      storeLng: (data['storeLng'] as num?)?.toDouble() ?? -97.4261,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      guaranteedPayout: (data['guaranteedPayout'] as num?)?.toDouble() ?? 8.50,
      customerTip: (data['customerTip'] as num?)?.toDouble() ?? 3.00,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 3.99,
      totalMiles: (data['totalMiles'] as num?)?.toDouble() ?? 3.2,
      itemCount: (data['itemCount'] as num?)?.toInt() ?? 1,
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'] || e.name == _snakeToCamel(data['status']?.toString()),
        orElse: () => OrderStatus.pendingDispatch,
      ),
      driverId: data['driverId']?.toString(),
      driverLat: (data['driverLat'] as num?)?.toDouble(),
      driverLng: (data['driverLng'] as num?)?.toDouble(),
      driverHeading: (data['driverHeading'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isHeavy: data['isHeavy'] == true,
      estimatedWeightLbs: (data['estimatedWeightLbs'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static String _snakeToCamel(String? text) {
    if (text == null) return '';
    if (text == 'pending_dispatch') return 'pendingDispatch';
    if (text == 'driver_assigned') return 'driverAssigned';
    if (text == 'out_for_delivery') return 'outForDelivery';
    return text;
  }
}
