// File: lib/providers/cart_provider.dart

import 'package:flutter/foundation.dart';

class CartState {
  final List<Map<String, dynamic>> items;
  final int totalCount;
  final double subtotal;

  const CartState({
    this.items = const [],
    this.totalCount = 0,
    this.subtotal = 0.0,
  });

  factory CartState.fromItems(List<Map<String, dynamic>> items) {
    int count = 0;
    double sum = 0.0;
    for (final i in items) {
      final qty = (i['quantity'] as num?)?.toInt() ?? 1;
      final price = (i['price'] as num?)?.toDouble() ?? 0.0;
      count += qty;
      sum += (price * qty);
    }
    return CartState(items: List.unmodifiable(items), totalCount: count, subtotal: sum);
  }
}

class CartProvider extends ValueNotifier<CartState> {
  CartProvider._() : super(const CartState());
  static final CartProvider instance = CartProvider._();

  void addItem(Map<String, dynamic> item) {
    final current = List<Map<String, dynamic>>.from(value.items);
    final idx = current.indexWhere((i) => i['id'] == item['id']);
    if (idx >= 0) {
      current[idx] = Map<String, dynamic>.from(current[idx]);
      current[idx]['quantity'] = (current[idx]['quantity'] as int) + 1;
    } else {
      current.add({...item, 'quantity': 1});
    }
    value = CartState.fromItems(current);
  }

  void updateQuantity(String id, int delta) {
    final current = List<Map<String, dynamic>>.from(value.items);
    final idx = current.indexWhere((i) => i['id'] == id);
    if (idx < 0) return;

    final newQty = (current[idx]['quantity'] as int) + delta;
    if (newQty <= 0) {
      current.removeAt(idx);
    } else {
      current[idx] = Map<String, dynamic>.from(current[idx]);
      current[idx]['quantity'] = newQty;
    }
    value = CartState.fromItems(current);
  }

  void clear() {
    value = const CartState();
  }
}
