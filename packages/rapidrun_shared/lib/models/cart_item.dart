// File: packages/rapidrun_shared/lib/models/cart_item.dart

import 'package:flutter/foundation.dart';

@immutable
class CartItem {
  final String id;
  final String storeId;
  final String storeName;
  final String title;
  final String? subtitle;
  final double price;
  final String imageUrl;
  final int quantity;
  final String? promoBadge;

  const CartItem({
    required this.id,
    this.storeId = 'store_bbw_westover',
    String? storeName,
    String? brand,
    String? title,
    String? name,
    String? subtitle,
    String? size,
    required this.price,
    this.imageUrl = '',
    this.quantity = 1,
    this.promoBadge,
  })  : storeName = storeName ?? brand ?? 'Bath & Body Works',
        title = title ?? name ?? 'Item',
        subtitle = subtitle ?? size;

  // Backward compatibility alias getters
  String get name => title;
  String get brand => storeName;
  String get size => subtitle ?? 'Regular';

  CartItem copyWith({
    int? quantity,
    double? price,
    String? title,
    String? subtitle,
    String? storeId,
    String? storeName,
    String? imageUrl,
    String? promoBadge,
  }) {
    return CartItem(
      id: id,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      promoBadge: promoBadge ?? this.promoBadge,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'storeId': storeId,
    'storeName': storeName,
    'title': title,
    'subtitle': subtitle,
    'price': price,
    'imageUrl': imageUrl,
    'quantity': quantity,
    'promoBadge': promoBadge,
    // Alias fields for backward compatibility
    'name': title,
    'brand': storeName,
    'size': subtitle ?? 'Regular',
  };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    id: (map['id'] ?? '').toString(),
    storeId: (map['storeId'] ?? 'store_bbw_westover').toString(),
    storeName: (map['storeName'] ?? map['brand'] ?? 'Bath & Body Works').toString(),
    title: (map['title'] ?? map['name'] ?? 'Item').toString(),
    subtitle: map['subtitle']?.toString() ?? map['size']?.toString(),
    price: (map['price'] as num?)?.toDouble() ?? 0.0,
    imageUrl: (map['imageUrl'] ?? '').toString(),
    quantity: (map['quantity'] ?? map['qty'] ?? 1) as int,
    promoBadge: map['promoBadge']?.toString(),
  );
}
