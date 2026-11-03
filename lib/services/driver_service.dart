import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driver.dart';

/// Local-only driver state manager (pre-Firestore). In production this will sync remotely.
class DriverService extends ChangeNotifier {
  DriverService._();
  static final DriverService instance = DriverService._();

  static const _prefsKey = 'rapidrun_drivers_v1';
  final List<DriverProfile> _drivers = [];
  bool _bootstrapped = false;
  final Map<String, Timer> _simTimers = {};
  final _rand = math.Random();

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ?? '';
      _drivers
        ..clear()
        ..addAll(DriverProfile.decodeList(raw));
    } catch (_) {}
    _bootstrapped = true;
    notifyListeners();
  }

  List<DriverProfile> get drivers => List.unmodifiable(_drivers);

  DriverProfile? getById(String id) => _drivers.firstWhere(
    (d) => d.id == id,
    orElse: () =>
        const DriverProfile(id: '_none', displayName: 'none', online: false),
  );

  Future<DriverProfile> upsertDriver(String id, {required String name}) async {
    await bootstrap();
    final idx = _drivers.indexWhere((d) => d.id == id);
    DriverProfile profile;
    if (idx == -1) {
      profile = DriverProfile(id: id, displayName: name, online: false);
      _drivers.add(profile);
    } else {
      profile = _drivers[idx].copyWith(displayName: name);
      _drivers[idx] = profile;
    }
    await _persist();
    notifyListeners();
    return profile;
  }

  Future<void> setOnline(String id, bool online) async {
    final idx = _drivers.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    _drivers[idx] = _drivers[idx].copyWith(online: online);
    await _persist();
    notifyListeners();
  }

  Future<void> assignOrder(String driverId, String orderId) async {
    final idx = _drivers.indexWhere((d) => d.id == driverId);
    if (idx == -1) return;
    _drivers[idx] = _drivers[idx].copyWith(activeOrderId: orderId);
    await _persist();
    notifyListeners();
  }

  Future<void> clearOrder(String driverId) async {
    final idx = _drivers.indexWhere((d) => d.id == driverId);
    if (idx == -1) return;
    _drivers[idx] = _drivers[idx].copyWith(activeOrderId: null);
    await _persist();
    notifyListeners();
  }

  Future<void> heartbeat(
    String driverId,
    double lat,
    double lng, {
    bool notify = false,
  }) async {
    final idx = _drivers.indexWhere((d) => d.id == driverId);
    if (idx == -1) return;
    _drivers[idx] = _drivers[idx].copyWith(
      lastLat: lat,
      lastLng: lng,
      lastPingAt: DateTime.now(),
    );
    await _persist();
    if (notify) notifyListeners();
  }

  /// Starts a debug heartbeat simulation that jitters the driver's location.
  void startHeartbeatSimulation(String driverId) {
    // Only in debug via assert.
    var allow = false;
    assert(() {
      allow = true;
      return true;
    }());
    if (!allow) return;
    if (_simTimers.containsKey(driverId)) return;
    // Pick a pseudo base coordinate (example downtown). Could later derive from order address.
    final baseLat = 37.7749; // placeholder
    final baseLng = -122.4194;
    _simTimers[driverId] = Timer.periodic(const Duration(seconds: 15), (
      _,
    ) async {
      final lat = baseLat + (_rand.nextDouble() - 0.5) * 0.01; // ~1km box
      final lng = baseLng + (_rand.nextDouble() - 0.5) * 0.01;
      await heartbeat(driverId, lat, lng, notify: true);
    });
  }

  void stopHeartbeatSimulation(String driverId) {
    _simTimers.remove(driverId)?.cancel();
  }

  @override
  void dispose() {
    for (final t in _simTimers.values) {
      t.cancel();
    }
    _simTimers.clear();
    super.dispose();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, DriverProfile.encodeList(_drivers));
    } catch (_) {}
  }
}
