import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import 'favorites_cart_service.dart';
import 'product_catalog_service.dart';
import '../models/payment_method.dart';
import '../models/address.dart';
import 'log_service.dart';

/// Local persistence order service (MVP). Later can sync to Firestore.
class OrdersService extends ChangeNotifier {
  static final OrdersService instance = OrdersService._();
  OrdersService._();

  final List<Order> _orders = [];
  bool _bootstrapped = false;
  static const _prefsKey = 'rapidrun_orders_v1';
  static const _cloudPageSize = 20;
  bool _cloudInitialized = false;
  cf.DocumentSnapshot? _lastPageCursor;
  bool _exhausted = false; // no more pages
  StreamSubscription? _ordersSub; // realtime listener subscription
  // --- Pending operation queue (offline / retry) ---
  static const _pendingOpsKey = 'rapidrun_order_ops_v1';
  final List<_PendingOrderOp> _pending = [];
  bool _flushing = false;
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  cf.CollectionReference<Map<String, dynamic>> get _ordersCol =>
      cf.FirebaseFirestore.instance.collection('orders');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ?? '';
      _orders
        ..clear()
        ..addAll(Order.decodeList(raw));
      // Load pending ops
      final opsRaw = prefs.getString(_pendingOpsKey);
      if (opsRaw != null && opsRaw.isNotEmpty) {
        try {
          _pending
            ..clear()
            ..addAll(_PendingOrderOp.decodeList(opsRaw));
          pendingCount.value = _pending.length;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[OrdersService] pending ops decode error: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode)
        debugPrint('[OrdersService] local bootstrap load error: $e');
    }
    _bootstrapped = true;
    // Optionally hydrate initial cloud page (non-blocking) if feature enabled & user signed in
    if (AppConfig.enableCloudOrders && _uid != null) {
      // fire and forget; caller can await ensureCloudHydrated if needed
      unawaited(_initCloudFirstPage());
    }
    notifyListeners();
  }

  /// Public method to explicitly trigger a refresh from Firestore when cloud orders enabled.
  Future<void> refreshFromCloud() async {
    if (!AppConfig.enableCloudOrders || _uid == null) return;
    _cloudInitialized = false;
    _lastPageCursor = null;
    _exhausted = false;
    await _ordersSub?.cancel();
    await _initCloudFirstPage();
  }

  Future<void> _initCloudFirstPage() async {
    if (_cloudInitialized || !AppConfig.enableCloudOrders || _uid == null)
      return;
    try {
      final snap = await _ordersCol
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(_cloudPageSize)
          .get();
      _mergeCloudSnapshot(snap, replace: true);
      if (snap.docs.isNotEmpty) {
        _lastPageCursor = snap.docs.last;
      }
      if (snap.docs.length < _cloudPageSize) _exhausted = true;
      _cloudInitialized = true;
      // Start realtime listener for the newest window of orders
      _ordersSub = _ordersCol
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(_cloudPageSize)
          .snapshots()
          .listen((liveSnap) {
            _mergeCloudSnapshot(liveSnap, replace: true);
          });
    } catch (e) {
      if (kDebugMode)
        debugPrint('[OrdersService] initCloudFirstPage error: $e');
      // fallback remains local orders only
    }
  }

  Future<void> loadMoreCloud() async {
    if (!AppConfig.enableCloudOrders || _uid == null || _exhausted) return;
    if (_lastPageCursor == null) {
      await _initCloudFirstPage();
      return;
    }
    try {
      final snap = await _ordersCol
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastPageCursor!)
          .limit(_cloudPageSize)
          .get();
      _mergeCloudSnapshot(snap, replace: false);
      if (snap.docs.isNotEmpty) {
        _lastPageCursor = snap.docs.last;
      }
      if (snap.docs.length < _cloudPageSize) _exhausted = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[OrdersService] loadMoreCloud error: $e');
    }
  }

  void _mergeCloudSnapshot(
    cf.QuerySnapshot<Map<String, dynamic>> snap, {
    required bool replace,
  }) {
    if (snap.docs.isEmpty) {
      if (replace) notifyListeners();
      return;
    }
    final cloudOrders = snap.docs.map((d) => _fromFirestore(d.data())).toList();
    if (replace) {
      _orders
        ..clear()
        ..addAll(cloudOrders);
    } else {
      // Append only new ones (avoid duplicates by id)
      for (final o in cloudOrders) {
        if (_orders.indexWhere((e) => e.id == o.id) == -1) {
          _orders.add(o);
        }
      }
    }
    // Ensure local cache persistence remains (so offline still works)
    unawaited(_persist());
    notifyListeners();
  }

  List<Order> get orders => List.unmodifiable(_orders);
  Order? getById(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Order> placeOrder({
    required Address address,
    required PaymentMethodSummary payment,
  }) async {
    await bootstrap();
    await ProductCatalogService.instance.ensureLoaded();
    final cart = CartService.instance.items;
    final items = <OrderLineItem>[];
    double subtotal = 0;
    cart.forEach((id, qty) {
      final prod = ProductCatalogService.instance.get(id);
      final price = prod?.price ?? 0;
      subtotal += price * qty;
      items.add(
        OrderLineItem(
          productId: id,
          name: prod?.name ?? id,
          unitPrice: price,
          quantity: qty,
        ),
      );
    });
    // Simple flat tax placeholder (7%)
    final tax = double.parse((subtotal * 0.07).toStringAsFixed(2));
    final total = subtotal + tax;
    final order = Order(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      status: OrderStatus.pending,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      payment: OrderSummaryPayment(
        methodId: payment.id,
        brand: payment.brand,
        last4: payment.last4,
      ),
      address: OrderSummaryAddress(
        id: address.id,
        line1: address.line1,
        line2: address.line2,
        city: address.city,
        state: address.state,
        postalCode: address.postalCode,
        fullName: address.fullName,
      ),
    );
    _orders.insert(0, order);
    // Cloud write if enabled & signed in
    if (AppConfig.enableCloudOrders && _uid != null) {
      unawaited(_writeOrderToCloud(order));
      _enqueueOp(_PendingOrderOp.create(order.id));
    }
    await _persist();
    notifyListeners();
    // Clear cart after save
    await CartService.instance.clear();
    LogService.instance.log(
      'placeOrder ${order.id} items=${items.length} total=${order.total}',
      category: 'orders',
    );
    return order;
  }

  Future<void> markProcessing(String id) async =>
      _updateStatus(id, OrderStatus.processing);
  Future<void> markCompleted(String id) async =>
      _updateStatus(id, OrderStatus.completed);
  Future<void> markFailed(String id) async =>
      _updateStatus(id, OrderStatus.failed);
  Future<void> markAssigned(String id, String driverId) async {
    _mutate(
      id,
      (o) => o.copyWith(
        status: OrderStatus.assigned,
        driverId: driverId,
        assignedAt: DateTime.now(),
      ),
    );
  }

  Future<void> markShoppingStarted(String id) async {
    _mutate(
      id,
      (o) => o.copyWith(
        status: OrderStatus.shopping,
        shoppingStartedAt: DateTime.now(),
      ),
    );
  }

  Future<void> markShoppingCompleted(String id) async {
    _mutate(
      id,
      (o) => o.copyWith(
        status: OrderStatus.ready_for_delivery,
        shoppingCompletedAt: DateTime.now(),
      ),
    );
  }

  Future<void> markEnRoute(String id) async {
    _mutate(
      id,
      (o) => o.copyWith(
        status: OrderStatus.enroute,
        deliveryStartedAt: DateTime.now(),
      ),
    );
  }

  Future<void> markDelivered(String id) async {
    _mutate(
      id,
      (o) => o.copyWith(
        status: OrderStatus.delivered,
        deliveredAt: DateTime.now(),
      ),
    );
  }

  Future<void> markCanceled(String id) async {
    _mutate(
      id,
      (o) =>
          o.copyWith(status: OrderStatus.canceled, canceledAt: DateTime.now()),
    );
  }

  Future<void> incrementSubstitutionRequests(String id) async {
    _mutate(
      id,
      (o) => o.copyWith(
        substitutionRequestCount: o.substitutionRequestCount + 1,
        awaitingSubstitutionApproval: true,
        status: OrderStatus.awaiting_substitution,
      ),
    );
  }

  Future<void> clearSubstitutionAwait(
    String id, {
    bool backToShopping = true,
  }) async {
    _mutate(
      id,
      (o) => o.copyWith(
        awaitingSubstitutionApproval: false,
        status: backToShopping ? OrderStatus.shopping : o.status,
      ),
    );
  }

  /// Apply an approved substitution by replacing the first matching productId's name.
  Future<void> applySubstitution({
    required String orderId,
    required String originalProductId,
    required String newName,
    double? newUnitPrice,
  }) async {
    _mutate(orderId, (o) {
      double? oldLineTotal;
      double? newLineTotal;
      final newItems = o.items.map((li) {
        if (li.productId == originalProductId) {
          final updatedPrice = newUnitPrice ?? li.unitPrice;
          oldLineTotal = li.lineTotal;
          final updated = OrderLineItem(
            productId: li.productId,
            name: newName,
            unitPrice: updatedPrice,
            quantity: li.quantity,
          );
          newLineTotal = updated.lineTotal;
          return updated;
        }
        return li;
      }).toList();
      double newSubtotal = o.subtotal;
      double newTax = o.tax;
      double newTotal = o.total;
      if (oldLineTotal != null &&
          newLineTotal != null &&
          oldLineTotal != newLineTotal) {
        // Adjust subtotal by delta then recompute tax & total.
        final delta = newLineTotal! - oldLineTotal!;
        newSubtotal = double.parse((newSubtotal + delta).toStringAsFixed(2));
        newTax = double.parse((newSubtotal * 0.07).toStringAsFixed(2));
        newTotal = newSubtotal + newTax;
      }
      return o.copyWith(
        items: newItems,
        awaitingSubstitutionApproval: false,
        subtotal: newSubtotal,
        tax: newTax,
        total: newTotal,
      ); // Totals unchanged in model pending financial fields extension
    });
  }

  Future<void> _updateStatus(String id, OrderStatus s) async {
    final idx = _orders.indexWhere((o) => o.id == id);
    if (idx == -1) return;
    final existing = _orders[idx];
    _orders[idx] = existing.copyWith(status: s);
    await _persist();
    notifyListeners();
    if (AppConfig.enableCloudOrders && _uid != null) {
      _enqueueOp(_PendingOrderOp.status(existing.id, s));
    }
  }

  void _mutate(String id, Order Function(Order) transform) {
    final idx = _orders.indexWhere((o) => o.id == id);
    if (idx == -1) return;
    final before = _orders[idx];
    final updated = transform(before);
    _orders[idx] = updated;
    LogService.instance.log(
      'update ${updated.id} status=${updated.status.name}',
      category: 'orders',
    );
    if (AppConfig.enableCloudOrders && _uid != null) {
      // Use a 'full' sync op since an arbitrary mutation occurred.
      _enqueueOp(_PendingOrderOp.full(updated.id));
    }
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, Order.encodeList(_orders));
    } catch (e) {
      if (kDebugMode) debugPrint('[OrdersService] persist error: $e');
    }
  }

  /// Upload existing local orders that don't yet exist in Firestore.
  Future<void> migrateLocalOrdersToCloud() async {
    if (!AppConfig.enableCloudOrders || _uid == null) return;
    await bootstrap();
    for (final o in _orders) {
      try {
        final doc = await _ordersCol.doc(o.id).get();
        if (!doc.exists) {
          await _ordersCol.doc(o.id).set(_toFirestore(o));
        }
      } catch (e) {
        if (kDebugMode)
          debugPrint('[OrdersService] migrate upload failed for ${o.id}: $e');
      }
    }
    // After migration try flush any queued ops
    unawaited(_flushPending());
  }

  Map<String, dynamic> _toFirestore(Order o) {
    final json = o.toJson();
    // Additional top-level fields for querying
    json['userId'] = _uid; // denormalized for query
    json['createdAt'] =
        o.createdAt.millisecondsSinceEpoch; // numeric for ordering
    return json;
  }

  Order _fromFirestore(Map<String, dynamic> data) {
    // Convert numeric timestamp back
    if (data['createdAt'] is int) {
      data = Map<String, dynamic>.from(data);
      final ts = data['createdAt'] as int;
      data['createdAt'] = DateTime.fromMillisecondsSinceEpoch(
        ts,
      ).toIso8601String();
    }
    return Order.fromJson(data);
  }

  Future<void> _writeOrderToCloud(Order order) async {
    try {
      await _ordersCol.doc(order.id).set(_toFirestore(order));
      LogService.instance.log('cloud write ok ${order.id}', category: 'orders');
    } catch (e, st) {
      LogService.instance.log(
        'cloud write fail ${order.id}',
        category: 'orders',
        error: e,
        stack: st,
      );
      rethrow;
    }
  }

  Future<void> _updateCloudStatus(String id, OrderStatus status) async {
    try {
      await _ordersCol.doc(id).update({'status': status.name});
    } catch (e) {
      if (kDebugMode) debugPrint('[OrdersService] updateCloudStatus error: $e');
    }
  }

  // ---------------- Pending Ops Queue Logic -----------------
  void _enqueueOp(_PendingOrderOp op) {
    _pending.add(op);
    pendingCount.value = _pending.length;
    LogService.instance.log(
      'enqueue ${op.type.name} for ${op.orderId} (len=${_pending.length})',
      category: 'orders',
    );
    unawaited(_persistPending());
    if (!_flushing) {
      unawaited(_flushPending());
    }
  }

  // (Removed unused _scheduleFlush method after logging instrumentation)

  Future<void> _flushPending() async {
    if (_flushing) return;
    if (_pending.isEmpty) return;
    _flushing = true;
    LogService.instance.log(
      'flush start count=${_pending.length}',
      category: 'orders',
    );
    // Copy to avoid mutation during iteration
    final ops = List<_PendingOrderOp>.from(_pending);
    for (final op in ops) {
      final idx = _pending.indexOf(op);
      if (idx == -1) continue; // already removed
      try {
        if (_uid == null) break; // stop if signed out mid-flight
        switch (op.type) {
          case _PendingOpType.create:
            final ord = getById(op.orderId);
            if (ord != null) {
              await _ordersCol.doc(ord.id).set(_toFirestore(ord));
            }
            break;
          case _PendingOpType.status:
            await _updateCloudStatus(op.orderId, op.status!);
            break;
          case _PendingOpType.full:
            final ord = getById(op.orderId);
            if (ord != null) {
              await _ordersCol
                  .doc(ord.id)
                  .set(_toFirestore(ord), cf.SetOptions(merge: true));
            }
            break;
        }
        _pending.removeAt(idx);
        pendingCount.value = _pending.length;
        _persistPending();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[OrdersService] flush op failed (${op.type}) ${op.orderId}: $e',
          );
        }
        // If permission denied or not-found permanent errors desired, could remove.
        // For now leave in queue for later retry.
      }
    }
    _flushing = false;
    LogService.instance.log(
      'flush complete remaining=${_pending.length}',
      category: 'orders',
    );
  }

  Future<void> _persistPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingOpsKey,
        _PendingOrderOp.encodeList(_pending),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[OrdersService] persist pending error: $e');
    }
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    pendingCount.dispose();
    super.dispose();
  }
}

// ---------- Pending Order Operation Model (internal) ------------
enum _PendingOpType { create, status, full }

class _PendingOrderOp {
  final _PendingOpType type;
  final String orderId;
  final OrderStatus? status; // only for status op
  final DateTime createdAt;

  _PendingOrderOp._(this.type, this.orderId, this.status, this.createdAt);

  factory _PendingOrderOp.create(String orderId) =>
      _PendingOrderOp._(_PendingOpType.create, orderId, null, DateTime.now());
  factory _PendingOrderOp.status(String orderId, OrderStatus status) =>
      _PendingOrderOp._(_PendingOpType.status, orderId, status, DateTime.now());
  factory _PendingOrderOp.full(String orderId) =>
      _PendingOrderOp._(_PendingOpType.full, orderId, null, DateTime.now());

  Map<String, dynamic> toJson() => {
    't': type.name,
    'o': orderId,
    if (status != null) 's': status!.name,
    'c': createdAt.millisecondsSinceEpoch,
  };
  static _PendingOrderOp fromJson(Map<String, dynamic> json) {
    final type = _PendingOpType.values.firstWhere(
      (e) => e.name == json['t'],
      orElse: () => _PendingOpType.full,
    );
    final statusName = json['s'] as String?;
    OrderStatus? st;
    if (statusName != null) {
      st = OrderStatus.values.firstWhere(
        (e) => e.name == statusName,
        orElse: () => OrderStatus.pending,
      );
    }
    final created = DateTime.fromMillisecondsSinceEpoch(json['c'] as int? ?? 0);
    return _PendingOrderOp._(type, json['o'] as String, st, created);
  }

  static String encodeList(List<_PendingOrderOp> list) =>
      list.map((e) => e.toJson()).toList().toString();

  static List<_PendingOrderOp> decodeList(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    List<dynamic> data;
    try {
      data = jsonDecode(trimmed) as List<dynamic>;
    } catch (_) {
      // Fallback attempt: try to coerce to valid JSON by quoting keys & single quotes
      try {
        final repaired = trimmed.replaceAll("'", '"');
        data = jsonDecode(repaired) as List<dynamic>;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[OrdersService] pending ops final decode failure: $e');
        }
        return [];
      }
    }
    return data
        .whereType<Map>()
        .map((m) => _PendingOrderOp.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
