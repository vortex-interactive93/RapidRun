// File: lib/services/order_dispatch_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart' hide OrderStatus;
import '../models/dispatch_order.dart';

class OrderDispatchService {
  OrderDispatchService._();
  static final OrderDispatchService instance = OrderDispatchService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> submitTestOrder({
    String customerAddress = '9009 White Settlement Rd, White Settlement, TX 76108',
    String storeName = 'Bath & Body Works',
    String storeAddress = 'Westover Village, Fort Worth, TX',
    double customerTip = 5.00,
    double activeSurgeBonus = 2.50,
  }) async {
    final uniqueTimestamp = DateTime.now().millisecondsSinceEpoch;
    final orderId = 'ORD-${uniqueTimestamp.toString().substring(5)}';

    // Verified rooftop coordinates from Google Maps
    const double targetLat = 32.759602;
    const double targetLng = -97.471416;

    const double storeLat = 32.7485;
    const double storeLng = -97.4261;

    const double subtotal = 23.80;
    const double totalMiles = 3.8;
    const int itemCount = 3;

    final payoutBreakdown = DispatchPricingEngine.calculateDriverPayout(
      estimatedDistanceMiles: totalMiles,
      totalItemCount: itemCount,
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
      customerId: 'cust_sandbox_99',
      customerName: 'Thomas (Customer)',
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
      itemCount: itemCount,
      items: const [
        {
          'id': 'bbw_028005120',
          'name': 'A Thousand Wishes Fine Fragrance Mist',
          'quantity': 2,
          'price': 4.73,
          'aisle': 'Fragrance Wall • Bay 3',
          'imageUrl': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw1ef511b8/crop/028005120_crop.jpg?sw=500&sh=600&sm=fit',
          'size': '8 fl oz / 236 mL',
        },
        {
          'id': 'bbw_028028909',
          'name': 'In the Stars Fine Fragrance Mist',
          'quantity': 1,
          'price': 5.95,
          'aisle': 'Fragrance Wall • Bay 1',
          'imageUrl': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw063e5270/crop/028028909_crop.jpg?sw=500&sh=600&sm=fit',
          'size': '8 fl oz / 236 mL',
        },
      ],
      status: OrderStatus.pendingDispatch,
      createdAt: DateTime.now(),
      isHeavy: false,
      estimatedWeightLbs: 2.8,
    );

    debugPrint('🚀 [CustomerApp] Dispatched dynamic payout order: $orderId (\$${payoutBreakdown.totalPayout})');
    final map = order.toMap();
    map['payoutBreakdown'] = payoutBreakdown.toMap();
    await _firestore.collection('orders').doc(orderId).set(map);
    return orderId;
  }
}
