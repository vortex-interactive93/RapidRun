// File: packages/rapidrun_shared/lib/state/cart_state.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart_item.dart';

class CartState extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _activeStoreId;
  String? _activeStoreName;
  bool _isHydrated = false;

  List<CartItem> get items => List.unmodifiable(_items.values);
  String? get activeStoreId => _activeStoreId;
  String? get activeStoreName => _activeStoreName;
  bool get isHydrated => _isHydrated;

  // --- DYNAMIC COMPUTED GETTERS (Zero Drift Possible) ---
  int get totalItemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => double.parse(
        _items.values.fold(0.0, (sum, item) {
          final effectivePrice = item.price > 0.0 ? item.price : 16.95;
          return sum + (effectivePrice * item.quantity);
        }).toStringAsFixed(2),
      );

  bool get isEmpty => _items.isEmpty;

  CartState() {
    _hydrateFromLocalStorage();
  }

  /// Hydrate cart immediately on cold app boot before UI renders
  Future<void> _hydrateFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawCartJson = prefs.getString('rapidrun_active_cart');

      if (rawCartJson != null && rawCartJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(rawCartJson);
        _items.clear();
        for (var itemMap in decodedList) {
          final item = CartItem.fromMap(Map<String, dynamic>.from(itemMap));
          final effectivePrice = item.price > 0.0 ? item.price : 16.95;
          final fixedItem = item.copyWith(price: effectivePrice);
          _items[fixedItem.id] = fixedItem;
          _activeStoreId = fixedItem.storeId;
          _activeStoreName = fixedItem.storeName;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CartState] Hydration warning: $e');
    } finally {
      _isHydrated = true;
      notifyListeners();
    }
  }

  Future<void> _persistToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_items.values.map((i) => i.toMap()).toList());
      await prefs.setString('rapidrun_active_cart', encoded);
    } catch (e) {
      debugPrint('⚠️ [CartState] Local persist failed: $e');
    }
  }

  /// Adds or increments an item. Automatically resets store context if switching stores.
  bool addItem(CartItem newItem, {bool forceClearExisting = true}) {
    if (_activeStoreId != null && _activeStoreId != newItem.storeId) {
      if (!forceClearExisting) return false;
      _items.clear();
    }

    _activeStoreId = newItem.storeId;
    _activeStoreName = newItem.storeName;

    final effectivePrice = newItem.price > 0.0 ? newItem.price : 16.95;
    final itemWithPrice = newItem.copyWith(price: effectivePrice);

    if (_items.containsKey(itemWithPrice.id)) {
      final existing = _items[itemWithPrice.id]!;
      _items[itemWithPrice.id] = existing.copyWith(
        quantity: existing.quantity + itemWithPrice.quantity,
        price: effectivePrice,
      );
    } else {
      _items[itemWithPrice.id] = itemWithPrice;
    }

    _persistToLocalStorage();
    notifyListeners();
    return true;
  }

  /// 1-Tap Re-order from previous batch orders
  void reorderBatch(List<CartItem> historicalItems, {bool forceClear = true}) {
    if (historicalItems.isEmpty) return;

    if (forceClear || (_activeStoreId != null && _activeStoreId != historicalItems.first.storeId)) {
      _items.clear();
    }

    _activeStoreId = historicalItems.first.storeId;
    _activeStoreName = historicalItems.first.storeName;

    for (final item in historicalItems) {
      final effectivePrice = item.price > 0.0 ? item.price : 16.95;
      final fixedItem = item.copyWith(price: effectivePrice);

      if (_items.containsKey(fixedItem.id)) {
        _items[fixedItem.id] = _items[fixedItem.id]!.copyWith(
          quantity: _items[fixedItem.id]!.quantity + fixedItem.quantity,
          price: effectivePrice,
        );
      } else {
        _items[fixedItem.id] = fixedItem;
      }
    }

    _persistToLocalStorage();
    notifyListeners();
  }

  /// Backward-compatibility alias for reorderBatch
  void reorderAll(List<CartItem> itemsToAdd) => reorderBatch(itemsToAdd, forceClear: true);

  void updateQuantity(String itemId, int newQuantity) {
    if (!_items.containsKey(itemId)) return;

    if (newQuantity <= 0) {
      _items.remove(itemId);
      if (_items.isEmpty) {
        _activeStoreId = null;
        _activeStoreName = null;
      }
    } else {
      _items[itemId] = _items[itemId]!.copyWith(quantity: newQuantity);
    }

    _persistToLocalStorage();
    notifyListeners();
  }

  /// Absolute wipe: Clears memory, resets store IDs, and forces all badges to 0
  Future<void> clearAll() async {
    _items.clear();
    _activeStoreId = null;
    _activeStoreName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rapidrun_active_cart');
    notifyListeners();
  }

  /// Alias for clearAll
  Future<void> clearCart() => clearAll();
}

// Global reactive singleton
final cartState = CartState();
