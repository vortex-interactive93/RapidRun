import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/product.dart';
import 'firebase_service.dart';
import 'product_catalog_service.dart';
import '../core/logger.dart';
import 'merge_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../analytics/event_names.dart';
import 'analytics_service.dart';

/// Favorites service with Firestore sync (per authenticated user).
class FavoritesService extends ChangeNotifier {
  static final FavoritesService instance = FavoritesService._();
  FavoritesService._();

  final Set<String> _favoriteIds = {};
  bool _listening = false;
  bool _bootstrapped = false;
  Timer? _debounce;
  bool _dirty = false;
  bool _mergedOnce = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _snapSub;
  StreamSubscription<User?>? _authSub;

  static const _prefsKey = 'rapidrun_favorites_v1';

  CollectionReference<Map<String, dynamic>> get _userCol =>
      FirebaseFirestore.instance.collection('users');

  DocumentReference<Map<String, dynamic>>? get _doc {
    final u = FirebaseService.user; // may be null early
    if (u == null) return null;
    return _userCol.doc(u.uid);
  }

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    // Load local cache first for instant UI.
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_prefsKey) ?? [];
      _favoriteIds
        ..clear()
        ..addAll(cached);
    } catch (_) {}
    _bootstrapped = true;
    notifyListeners();
    // React to auth changes for merge + listener attach.
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
    );
    // Touch subscription so analyzer treats field as used.
    // ignore: unnecessary_statements
    _authSub?.hashCode;
    // In case already logged in at startup.
    await _maybeMergeAndListen();
  }

  Future<void> _handleAuthChange(User? user) async {
    if (user == null) {
      // Signed out: stop listening so a new login can trigger fresh merge.
      await _snapSub?.cancel();
      _snapSub = null;
      _listening = false;
      _mergedOnce = false;
      return;
    }
    await _maybeMergeAndListen();
  }

  Future<void> _maybeMergeAndListen() async {
    if (FirebaseService.user == null) return; // guest
    if (!_mergedOnce) {
      try {
        final d = _doc!;
        final snap = await d.get();
        final remote =
            (snap.data()?['favorites'] as List?)?.cast<String>() ?? [];
        final before = Set<String>.from(_favoriteIds);
        final merged = mergeFavorites(_favoriteIds, remote);
        final changed = !setEquals(before, merged);
        if (changed) {
          _favoriteIds
            ..clear()
            ..addAll(merged);
          await _persistLocal();
          notifyListeners();
          log.i(
            'favorites',
            'Merged remote favorites',
            ctx: {
              'localBefore': before.length,
              'remote': remote.length,
              'after': _favoriteIds.length,
            },
          );
        }
        // Write merged union back (single write) if union expanded remote.
        if (remote.length != _favoriteIds.length) {
          await d.set({
            'favorites': _favoriteIds.toList(),
          }, SetOptions(merge: true));
        }
        _mergedOnce = true;
      } catch (_) {}
    }
    await ensureListener();
  }

  Future<void> ensureListener() async {
    if (_listening) return;
    final d = _doc;
    if (d == null) return; // guest mode
    _listening = true;
    _snapSub = d.snapshots().listen((snap) async {
      final remote = (snap.data()?['favorites'] as List?)?.cast<String>() ?? [];
      final before = Set<String>.from(_favoriteIds);
      final merged = mergeFavorites(_favoriteIds, remote);
      final changed = !setEquals(before, merged);
      if (changed) {
        _favoriteIds
          ..clear()
          ..addAll(merged);
        await _persistLocal();
        notifyListeners();
        log.d(
          'favorites',
          'Snapshot merge applied',
          ctx: {
            'before': before.length,
            'remote': remote.length,
            'after': _favoriteIds.length,
          },
        );
      }
    });
  }

  bool isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> toggle(String id) async {
    if (!_favoriteIds.remove(id)) {
      _favoriteIds.add(id);
    }
    _dirty = true;
    notifyListeners();
    await _persistLocal();
    _schedulePersist();
  }

  void _schedulePersist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!_dirty) return;
      _dirty = false;
      await _persistRemote();
    });
  }

  Future<void> _persistRemote() async {
    final d = _doc;
    if (d == null) return; // guest: keep local only
    try {
      await d.set({
        'favorites': _favoriteIds.toList(),
      }, SetOptions(merge: true));
    } catch (_) {
      // On failure, mark dirty again to retry on next cycle.
      _dirty = true;
      _schedulePersist();
    }
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _favoriteIds.toList());
    } catch (_) {}
  }

  List<String> get favorites => _favoriteIds.toList(growable: false);
}

/// Unified Cart Service Facade.
/// All cart state is strictly owned and persisted by [cartState] in rapidrun_shared.
class CartService extends ChangeNotifier {
  static final CartService instance = CartService._();
  CartService._() {
    cartState.addListener(notifyListeners);
  }

  void bootstrap() {}

  int get totalItems => cartState.totalItemCount;
  double get subtotal => cartState.subtotal;
  bool get isEmpty => cartState.isEmpty;

  Map<String, int> get items {
    return {
      for (final item in cartState.items) item.id: item.quantity,
    };
  }

  int quantityFor(String productId) {
    for (final item in cartState.items) {
      if (item.id == productId) return item.quantity;
    }
    return 0;
  }

  Future<void> add(String productId, int quantity, {Product? productMetadata}) async {
    if (quantity <= 0) return;
    final Product? resolved = productMetadata ??
        ProductCatalogService.instance.get(productId) ??
        ProductRepository.sampleProducts.cast<Product?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );

    final item = CartItem(
      id: productId,
      storeId: resolved?.store ?? cartState.activeStoreId ?? 'store_bbw_westover',
      storeName: resolved?.brand ?? cartState.activeStoreName ?? 'Bath & Body Works',
      title: resolved?.name ?? (resolved != null ? resolved.name : 'Item $productId'),
      price: resolved?.price ?? 0.0,
      subtitle: resolved?.unitShort ?? resolved?.unit ?? 'Regular',
      imageUrl: resolved?.imageUrl ?? '',
      quantity: quantity,
    );

    cartState.addItem(item, forceClearExisting: false);
  }

  Future<void> addProduct(Product product, int quantity) async {
    await add(product.id, quantity, productMetadata: product);
  }

  Future<void> addVariant(Product product, int quantity) async {
    await add(product.id, quantity, productMetadata: product);
  }

  Product? getVariant(String id) {
    return ProductCatalogService.instance.get(id);
  }

  Future<void> setQuantity(String productId, int quantity) async {
    cartState.updateQuantity(productId, quantity);
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    cartState.updateQuantity(productId, quantity);
  }

  Future<void> clear() async {
    await cartState.clearAll();
  }
}
