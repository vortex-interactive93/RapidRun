import 'dart:convert';
import 'order_status.dart';

class OrderLineItem {
  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;
  const OrderLineItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });
  double get lineTotal => unitPrice * quantity;
  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };
  static OrderLineItem fromJson(Map<String, dynamic> j) => OrderLineItem(
        productId: j['productId'] as String,
        name: j['name'] as String,
        unitPrice: (j['unitPrice'] as num).toDouble(),
        quantity: j['quantity'] as int,
      );
}

class OrderSummaryPayment {
  final String methodId;
  final String brand;
  final String last4;
  const OrderSummaryPayment({
    required this.methodId,
    required this.brand,
    required this.last4,
  });
  Map<String, dynamic> toJson() => {
        'methodId': methodId,
        'brand': brand,
        'last4': last4,
      };
  static OrderSummaryPayment fromJson(Map<String, dynamic> j) =>
      OrderSummaryPayment(
        methodId: j['methodId'] as String,
        brand: j['brand'] as String,
        last4: j['last4'] as String,
      );
}

class OrderSummaryAddress {
  final String id;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final String fullName;
  const OrderSummaryAddress({
    required this.id,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.fullName,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'line1': line1,
        'line2': line2,
        'city': city,
        'state': state,
        'postalCode': postalCode,
        'fullName': fullName,
      };
  static OrderSummaryAddress fromJson(Map<String, dynamic> j) =>
      OrderSummaryAddress(
        id: j['id'] as String,
        line1: j['line1'] as String,
        line2: j['line2'] as String?,
        city: j['city'] as String,
        state: j['state'] as String,
        postalCode: j['postalCode'] as String,
        fullName: j['fullName'] as String,
      );
}

/// Basic geolocation used for driver & delivery tracking.
class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);
  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
  static LatLngPoint fromJson(Map<String, dynamic> j) =>
      LatLngPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());
}

class Order {
  final String id;
  final DateTime createdAt;
  final OrderStatus status;
  final List<OrderLineItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final OrderSummaryPayment payment;
  final OrderSummaryAddress address;
  final String? driverId;
  final DateTime? assignedAt;
  final DateTime? shoppingStartedAt;
  final DateTime? shoppingCompletedAt;
  final DateTime? deliveryStartedAt;
  final DateTime? deliveredAt;
  final DateTime? canceledAt;
  final bool awaitingSubstitutionApproval;
  final int substitutionRequestCount;
  const Order({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.payment,
    required this.address,
    this.driverId,
    this.assignedAt,
    this.shoppingStartedAt,
    this.shoppingCompletedAt,
    this.deliveryStartedAt,
    this.deliveredAt,
    this.canceledAt,
    this.awaitingSubstitutionApproval = false,
    this.substitutionRequestCount = 0,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'payment': payment.toJson(),
        'address': address.toJson(),
        if (driverId != null) 'driverId': driverId,
        if (assignedAt != null) 'assignedAt': assignedAt!.toIso8601String(),
        if (shoppingStartedAt != null)
          'shoppingStartedAt': shoppingStartedAt!.toIso8601String(),
        if (shoppingCompletedAt != null)
          'shoppingCompletedAt': shoppingCompletedAt!.toIso8601String(),
        if (deliveryStartedAt != null)
          'deliveryStartedAt': deliveryStartedAt!.toIso8601String(),
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
        if (canceledAt != null) 'canceledAt': canceledAt!.toIso8601String(),
        if (awaitingSubstitutionApproval) 'awaitingSubstitutionApproval': true,
        if (substitutionRequestCount > 0)
          'substitutionRequestCount': substitutionRequestCount,
      };
  static Order fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        status: OrderStatus.values.firstWhere((e) => e.name == j['status']),
        items: (j['items'] as List)
            .map((e) => OrderLineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (j['subtotal'] as num).toDouble(),
        tax: (j['tax'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
        payment:
            OrderSummaryPayment.fromJson(j['payment'] as Map<String, dynamic>),
        address:
            OrderSummaryAddress.fromJson(j['address'] as Map<String, dynamic>),
        driverId: j['driverId'] as String?,
        assignedAt: j['assignedAt'] != null
            ? DateTime.tryParse(j['assignedAt'] as String)
            : null,
        shoppingStartedAt: j['shoppingStartedAt'] != null
            ? DateTime.tryParse(j['shoppingStartedAt'] as String)
            : null,
        shoppingCompletedAt: j['shoppingCompletedAt'] != null
            ? DateTime.tryParse(j['shoppingCompletedAt'] as String)
            : null,
        deliveryStartedAt: j['deliveryStartedAt'] != null
            ? DateTime.tryParse(j['deliveryStartedAt'] as String)
            : null,
        deliveredAt: j['deliveredAt'] != null
            ? DateTime.tryParse(j['deliveredAt'] as String)
            : null,
        canceledAt: j['canceledAt'] != null
            ? DateTime.tryParse(j['canceledAt'] as String)
            : null,
        awaitingSubstitutionApproval:
            (j['awaitingSubstitutionApproval'] as bool?) ?? false,
        substitutionRequestCount: (j['substitutionRequestCount'] as int?) ?? 0,
      );

  Order copyWith({
    OrderStatus? status,
    String? driverId,
    DateTime? assignedAt,
    DateTime? shoppingStartedAt,
    DateTime? shoppingCompletedAt,
    DateTime? deliveryStartedAt,
    DateTime? deliveredAt,
    DateTime? canceledAt,
    bool? awaitingSubstitutionApproval,
    int? substitutionRequestCount,
    List<OrderLineItem>? items,
    double? subtotal,
    double? tax,
    double? total,
  }) {
    return Order(
      id: id,
      createdAt: createdAt,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      payment: payment,
      address: address,
      driverId: driverId ?? this.driverId,
      assignedAt: assignedAt ?? this.assignedAt,
      shoppingStartedAt: shoppingStartedAt ?? this.shoppingStartedAt,
      shoppingCompletedAt: shoppingCompletedAt ?? this.shoppingCompletedAt,
      deliveryStartedAt: deliveryStartedAt ?? this.deliveryStartedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      canceledAt: canceledAt ?? this.canceledAt,
      awaitingSubstitutionApproval:
          awaitingSubstitutionApproval ?? this.awaitingSubstitutionApproval,
      substitutionRequestCount:
          substitutionRequestCount ?? this.substitutionRequestCount,
    );
  }

  static String encodeList(List<Order> list) =>
      json.encode(list.map((e) => e.toJson()).toList());
  static List<Order> decodeList(String raw) {
    if (raw.isEmpty) return [];
    final list = json.decode(raw) as List;
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }
}
