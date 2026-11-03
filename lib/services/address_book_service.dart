import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/address.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple address book with local persistence + optional Firestore sync when authed.
class AddressBookService extends ChangeNotifier {
  static final AddressBookService instance = AddressBookService._();
  AddressBookService._();

  final List<Address> _addresses = [];
  bool _bootstrapped = false;
  bool _dirty = false;
  Timer? _debounce;
  static const _prefsKey = 'rapidrun_addresses_v1';

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
      _addresses
        ..clear()
        ..addAll(Address.decodeList(raw));
    } catch (_) {}
    _bootstrapped = true;
    notifyListeners();
    await _maybeMergeRemote();
  }

  Future<void> _maybeMergeRemote() async {
    final d = _doc;
    if (d == null) return; // guest
    try {
      final snap = await d.get();
      final remoteRaw =
          (snap.data()?['addresses'] as List?)?.cast<Map<String, dynamic>>() ??
          [];
      bool changed = false;
      for (final r in remoteRaw) {
        final addr = Address.fromJson(r);
        if (_addresses.indexWhere((a) => a.id == addr.id) == -1) {
          _addresses.add(addr);
          changed = true;
        }
      }
      if (changed) {
        await _persistLocal();
        notifyListeners();
      }
      // push union back (one-time) if size differs
      if (remoteRaw.length != _addresses.length) {
        await d.set({
          'addresses': _addresses.map((e) => e.toJson()).toList(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  List<Address> get all => List.unmodifiable(_addresses);
  Address? get defaultAddress {
    if (_addresses.isEmpty) return null;
    final d = _addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => _addresses.first,
    );
    return d;
  }

  Future<void> upsert(Address a) async {
    final idx = _addresses.indexWhere((x) => x.id == a.id);
    if (a.isDefault) {
      for (var i = 0; i < _addresses.length; i++) {
        _addresses[i] = _addresses[i].copyWith(
          isDefault: _addresses[i].id == a.id,
        );
      }
    }
    if (idx == -1) {
      _addresses.add(a);
    } else {
      _addresses[idx] = a;
    }
    _dirty = true;
    notifyListeners();
    await _persistLocal();
    _scheduleRemote();
  }

  Future<void> remove(String id) async {
    _addresses.removeWhere((a) => a.id == id);
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
      await prefs.setString(_prefsKey, Address.encodeList(_addresses));
    } catch (_) {}
  }

  Future<void> _persistRemote() async {
    final d = _doc;
    if (d == null) return;
    try {
      await d.set({
        'addresses': _addresses.map((e) => e.toJson()).toList(),
      }, SetOptions(merge: true));
    } catch (_) {
      _dirty = true;
      _scheduleRemote();
    }
  }
}
