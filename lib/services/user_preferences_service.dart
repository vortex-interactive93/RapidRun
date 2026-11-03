import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'analytics_service.dart';
import '../analytics/event_names.dart';

/// Central strongly-typed user preferences with local cache + Firestore sync.
/// Guests: local only. Signed-in: merge local -> remote (first write) then live sync.
class UserPreferencesService extends ChangeNotifier {
  static final UserPreferencesService instance = UserPreferencesService._();
  UserPreferencesService._();

  static const _localKey = 'rapidrun_user_prefs_v1';

  bool _bootstrapped = false;
  bool _dirty = false;
  Timer? _debounce;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _remoteSub;

  // Core preference fields (initial sensible defaults)
  bool orderStatus = true;
  bool priceDrops = true;
  bool lowInventory = false;
  bool promos = true;
  bool substitutions = true;
  bool digestMode = false; // realtime by default
  int quietStartMinutes = 22 * 60; // 22:00
  int quietEndMinutes = 7 * 60; // 07:00

  String defaultStore = 'Aldi';
  bool glutenFreeFirst = false;
  bool hidePeanuts = false;
  bool hideTreeNuts = false;
  bool hideDairy = false;
  bool hideSoy = false;
  List<String> favoriteBrands = const [];
  List<String> blockedBrands = const [];
  bool metricUnits = false;
  bool showUnitPrice = true;
  String defaultSort = 'price';

  // Privacy / data
  bool personalizedRecs = true;
  bool allowTracking = true; // (consent)
  bool showCarbon = false;
  bool showWhy = true;

  // Accessibility
  double textScale = 1.0;
  bool highContrast = false;
  bool reduceMotion = false;
  bool voiceSearch = true;
  bool haptics = true;

  // Payments
  double defaultTip = 0.15;

  bool get isBootstrapped => _bootstrapped;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    await _loadLocal();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (_) => _attachOrDetachRemote(),
    );
    await _attachOrDetachRemote();
    _bootstrapped = true;
    notifyListeners();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw != null) {
        _applyMap(json.decode(raw) as Map<String, dynamic>, source: 'local');
      }
    } catch (_) {}
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localKey, json.encode(toMap()));
    } catch (_) {}
  }

  DocumentReference<Map<String, dynamic>>? get _doc {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(u.uid);
  }

  Future<void> _attachOrDetachRemote() async {
    try {
      await _remoteSub?.cancel();
      _remoteSub = null;
      final d = _doc;
      if (d == null) return; // guest mode
      final snap = await d.get();
      final remote = (snap.data()?['prefs'] as Map?)?.cast<String, dynamic>();
      if (remote == null) {
        // First time: push local snapshot
        await _persistRemote();
      } else {
        // Merge
        _applyMap(remote, source: 'remote');
        await _saveLocal();
        notifyListeners();
      }
      _remoteSub = d.snapshots().listen((snap) {
        final data = (snap.data()?['prefs'] as Map?)?.cast<String, dynamic>();
        if (data != null) {
          _applyMap(data, source: 'remote-stream');
          _saveLocal();
          notifyListeners();
        }
      }, onError: (e) {
        if (kDebugMode) debugPrint('[UserPreferencesService] stream error: $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[UserPreferencesService] remote sync error: $e');
    }
  }

  void _applyMap(Map<String, dynamic> m, {required String source}) {
    // Safe parse helpers
    T _v<T>(String k, T current) {
      final v = m[k];
      return v is T ? v : current;
    }

    orderStatus = _v('orderStatus', orderStatus);
    priceDrops = _v('priceDrops', priceDrops);
    lowInventory = _v('lowInventory', lowInventory);
    promos = _v('promos', promos);
    substitutions = _v('substitutions', substitutions);
    digestMode = _v('digestMode', digestMode);
    quietStartMinutes = _v('quietStartMinutes', quietStartMinutes);
    quietEndMinutes = _v('quietEndMinutes', quietEndMinutes);
    defaultStore = _v('defaultStore', defaultStore);
    glutenFreeFirst = _v('glutenFreeFirst', glutenFreeFirst);
    hidePeanuts = _v('hidePeanuts', hidePeanuts);
    hideTreeNuts = _v('hideTreeNuts', hideTreeNuts);
    hideDairy = _v('hideDairy', hideDairy);
    hideSoy = _v('hideSoy', hideSoy);
    favoriteBrands =
        (m['favoriteBrands'] as List?)?.cast<String>() ?? favoriteBrands;
    blockedBrands =
        (m['blockedBrands'] as List?)?.cast<String>() ?? blockedBrands;
    metricUnits = _v('metricUnits', metricUnits);
    showUnitPrice = _v('showUnitPrice', showUnitPrice);
    defaultSort = _v('defaultSort', defaultSort);
    personalizedRecs = _v('personalizedRecs', personalizedRecs);
    allowTracking = _v('allowTracking', allowTracking);
    showCarbon = _v('showCarbon', showCarbon);
    showWhy = _v('showWhy', showWhy);
    textScale = (m['textScale'] is num)
        ? (m['textScale'] as num).toDouble()
        : textScale;
    highContrast = _v('highContrast', highContrast);
    reduceMotion = _v('reduceMotion', reduceMotion);
    voiceSearch = _v('voiceSearch', voiceSearch);
    haptics = _v('haptics', haptics);
    defaultTip = (m['defaultTip'] is num)
        ? (m['defaultTip'] as num).toDouble()
        : defaultTip;
  }

  Map<String, dynamic> toMap() => {
    'orderStatus': orderStatus,
    'priceDrops': priceDrops,
    'lowInventory': lowInventory,
    'promos': promos,
    'substitutions': substitutions,
    'digestMode': digestMode,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
    'defaultStore': defaultStore,
    'glutenFreeFirst': glutenFreeFirst,
    'hidePeanuts': hidePeanuts,
    'hideTreeNuts': hideTreeNuts,
    'hideDairy': hideDairy,
    'hideSoy': hideSoy,
    'favoriteBrands': favoriteBrands,
    'blockedBrands': blockedBrands,
    'metricUnits': metricUnits,
    'showUnitPrice': showUnitPrice,
    'defaultSort': defaultSort,
    'personalizedRecs': personalizedRecs,
    'allowTracking': allowTracking,
    'showCarbon': showCarbon,
    'showWhy': showWhy,
    'textScale': textScale,
    'highContrast': highContrast,
    'reduceMotion': reduceMotion,
    'voiceSearch': voiceSearch,
    'haptics': haptics,
    'defaultTip': defaultTip,
  };

  void update(Map<String, dynamic> patch, {String? reason}) {
    _applyMap(patch, source: 'local-patch');
    _dirty = true;
    notifyListeners();
    _saveLocal();
    _schedulePersist();
    if (reason != null) {
      AnalyticsService.instance.log(
        AppEvent.preferencesUpdate,
        props: {
          'reason': reason,
          ...patch.map((k, v) => MapEntry('f_$k', v ?? 'null')),
        },
      );
    }
  }

  void _schedulePersist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!_dirty) return;
      _dirty = false;
      await _persistRemote();
    });
  }

  Future<void> _persistRemote() async {
    final d = _doc;
    if (d == null) return; // guest
    try {
      await d.set({'prefs': toMap()}, SetOptions(merge: true));
    } catch (_) {
      _dirty = true; // retry later
      _schedulePersist();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _remoteSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
