import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_method.dart';

class PaymentMethodsService extends ChangeNotifier {
  static final PaymentMethodsService instance = PaymentMethodsService._();
  PaymentMethodsService._();

  final List<PaymentMethodSummary> _methods = [];
  bool _bootstrapped = false;
  bool _dirty = false;
  Timer? _debounce;
  static const _prefsKey = 'rapidrun_payment_methods_v1';

  CollectionReference<Map<String, dynamic>> get _userCol =>
      FirebaseFirestore.instance.collection('users');
  DocumentReference<Map<String, dynamic>>? get _doc {
    final u = FirebaseService.user;
    if (u == null) return null;
    return _userCol.doc(u.uid);
  }

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ?? '';
      _methods
        ..clear()
        ..addAll(PaymentMethodSummary.decodeList(raw));
    } catch (_) {}
    _bootstrapped = true;
    notifyListeners();
    await _maybeMergeRemote();
  }

  Future<void> _maybeMergeRemote() async {
    final d = _doc;
    if (d == null) return;
    try {
      final snap = await d.get();
      final remote =
          (snap.data()?['paymentMethods'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      bool changed = false;
      for (final r in remote) {
        final pm = PaymentMethodSummary.fromJson(r);
        if (_methods.indexWhere((m) => m.id == pm.id) == -1) {
          _methods.add(pm);
          changed = true;
        }
      }
      if (changed) {
        await _persistLocal();
        notifyListeners();
      }
      if (remote.length != _methods.length) {
        await d.set({
          'paymentMethods': _methods.map((e) => e.toJson()).toList(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  List<PaymentMethodSummary> get all => List.unmodifiable(_methods);
  PaymentMethodSummary? get defaultMethod {
    if (_methods.isEmpty) return null;
    return _methods.firstWhere(
      (m) => m.isDefault,
      orElse: () => _methods.first,
    );
  }

  Future<void> upsert(PaymentMethodSummary m) async {
    final idx = _methods.indexWhere((x) => x.id == m.id);
    if (m.isDefault) {
      for (var i = 0; i < _methods.length; i++) {
        _methods[i] = _methods[i].copyWith(isDefault: _methods[i].id == m.id);
      }
    }
    if (idx == -1) {
      _methods.add(m);
    } else {
      _methods[idx] = m;
    }
    _dirty = true;
    notifyListeners();
    await _persistLocal();
    _scheduleRemote();
  }

  Future<void> remove(String id) async {
    _methods.removeWhere((m) => m.id == id);
    _dirty = true;
    notifyListeners();
    await _persistLocal();
    _scheduleRemote();
  }

  void _scheduleRemote() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!_dirty) return;
      _dirty = false;
      await _persistRemote();
    });
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        PaymentMethodSummary.encodeList(_methods),
      );
    } catch (_) {}
  }

  Future<void> _persistRemote() async {
    final d = _doc;
    if (d == null) return;
    try {
      await d.set({
        'paymentMethods': _methods.map((e) => e.toJson()).toList(),
      }, SetOptions(merge: true));
    } catch (_) {
      _dirty = true;
      _scheduleRemote();
    }
  }
}
