// File: lib/services/order_dispatch_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart' hide OrderStatus;
import '../models/dispatch_order.dart';

class OrderDispatchService {
  OrderDispatchService._();
  static final OrderDispatchService instance = OrderDispatchService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> submitLiveOrder({
    required List<Map<String, dynamic>> items,
    String customerAddress = '9009 White Settlement Rd, White Settlement, TX 76108',
    String customerName = 'Thomas (Customer)',
    String customerId = 'cust_live_01',
    String storeName = 'Bath & Body Works',
    String storeAddress = 'Westover Village, Fort Worth, TX',
    double customerTip = 5.00,
    double activeSurgeBonus = 2.50,
  }) async {
    final uniqueTimestamp = DateTime.now().millisecondsSinceEpoch;
    final orderId = 'ORD-${uniqueTimestamp.toString().substring(5)}';

    // Verified Fort Worth / Westover store coordinates
    const double targetLat = 32.759602;
    const double targetLng = -97.471416;
    const double storeLat = 32.7485;
    const double storeLng = -97.4261;

    double subtotal = 0.0;
    int totalItems = 0;
    final List<Map<String, dynamic>> itemsPayload = [];

    for (final raw in items) {
      final price = (raw['price'] ?? 16.95).toDouble();
      final qty = (raw['quantity'] ?? raw['qty'] ?? 1) as int;
      subtotal += (price * qty);
      totalItems += qty;

      itemsPayload.add({
        'id': raw['id'] ?? 'bbw_item',
        'name': raw['name'] ?? 'Bath & Body Works Item',
        'quantity': qty,
        'price': price,
        'imageUrl': raw['imageUrl'] ?? '',
        'size': raw['size'] ?? raw['unit'] ?? 'Standard',
        'aisle': 'Main Store Aisle',
      });
    }

    if (subtotal == 0.0) subtotal = 16.95;
    if (totalItems == 0) totalItems = 1;

    const double totalMiles = 3.8;

    final payoutBreakdown = DispatchPricingEngine.calculateDriverPayout(
      estimatedDistanceMiles: totalMiles,
      totalItemCount: totalItems,
      basketSubtotal: subtotal,
      activeSurgeBonus: activeSurgeBonus,
      customerTip: customerTip,
    );

    final deliveryFee = DispatchPricingEngine.calculateCustomerServiceFee(
      basketSubtotal: subtotal,
      estimatedDistanceMiles: totalMiles,
    );

    final order = DispatchOrder(
      id: orderId,
      customerId: customerId,
      customerName: customerName,
      customerAddress: customerAddress,
      customerLat: targetLat,
      customerLng: targetLng,
      storeId: 'store_bbw_westover',
      storeName: storeName,
      storeAddress: storeAddress,
      storeLat: storeLat,
      storeLng: storeLng,
      subtotal: subtotal,
      guaranteedPayout: payoutBreakdown.totalPayout,
      customerTip: customerTip,
      deliveryFee: deliveryFee,
      totalMiles: totalMiles,
      itemCount: totalItems,
      items: itemsPayload,
      status: OrderStatus.pendingDispatch,
      createdAt: DateTime.now(),
      isHeavy: false,
      estimatedWeightLbs: (totalItems * 0.8),
    );

    debugPrint('🚀 [CustomerApp] Dispatched live order $orderId with ${itemsPayload.length} cart SKUs (\$${payoutBreakdown.totalPayout} payout)');
    final map = order.toMap();
    map['payoutBreakdown'] = payoutBreakdown.toMap();
    await _firestore.collection('orders').doc(orderId).set(map);
    return orderId;
  }

  Future<String> submitTestOrder({
    String customerAddress = '9009 White Settlement Rd, White Settlement, TX 76108',
    String storeName = 'Bath & Body Works',
    String storeAddress = 'Westover Village, Fort Worth, TX',
    double customerTip = 5.00,
    double activeSurgeBonus = 2.50,
  }) async {
    return submitLiveOrder(
      items: [
        {
          'id': 'bbw_028034046',
          'name': 'A Thousand Wishes Body Wash',
          'quantity': 2,
          'price': 16.95,
          'size': '10 fl oz / 295 ml',
          'imageUrl': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwf68ba573/hires/028034046.jpg?sw=480&q=75&format=auto',
        },
      ],
      customerAddress: customerAddress,
      storeName: storeName,
      storeAddress: storeAddress,
      customerTip: customerTip,
      activeSurgeBonus: activeSurgeBonus,
    );
  }
}
