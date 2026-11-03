import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Lightweight combined connectivity + location permission status.
class DriverRuntimeStatus {
  final bool online; // network reachable
  final bool locationGranted;
  const DriverRuntimeStatus({
    required this.online,
    required this.locationGranted,
  });
  bool get healthy => online && locationGranted;
  DriverRuntimeStatus copyWith({bool? online, bool? locationGranted}) =>
      DriverRuntimeStatus(
        online: online ?? this.online,
        locationGranted: locationGranted ?? this.locationGranted,
      );
}

/// Broadcasts runtime status for UI banners / gating offer ingestion.
class ConnectivityPermissionService {
  ConnectivityPermissionService._();
  static final instance = ConnectivityPermissionService._();

  final _controller = StreamController<DriverRuntimeStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connSub; // plugin emits list
  DriverRuntimeStatus _current = const DriverRuntimeStatus(
    online: true,
    locationGranted: true,
  );

  Stream<DriverRuntimeStatus> get stream => _controller.stream;
  DriverRuntimeStatus get current => _current;

  Future<void> start() async {
    if (_connSub != null) return; // already started
    // Initial snapshots
    await _refreshLocation();
    await _refreshConnectivity();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
      _update(_current.copyWith(online: online));
    });
  }

  Future<void> refreshAll() async {
    await Future.wait([_refreshConnectivity(), _refreshLocation()]);
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
      _update(_current.copyWith(online: online));
    } catch (_) {}
  }

  Future<void> _refreshLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      bool granted =
          perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      if (!granted) {
        final req = await Geolocator.requestPermission();
        granted =
            req == LocationPermission.always ||
            req == LocationPermission.whileInUse;
      }
      _update(_current.copyWith(locationGranted: granted));
    } catch (_) {}
  }

  void _update(DriverRuntimeStatus next) {
    if (next.online == _current.online &&
        next.locationGranted == _current.locationGranted)
      return;
    _current = next;
    _controller.add(_current);
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    await _controller.close();
  }
}
