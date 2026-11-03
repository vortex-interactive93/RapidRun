import 'dart:async';
import 'package:rapidrun_shared/rapidrun_shared.dart';

/// Stub location service – replace with actual geolocator + permission handling.
class DriverLocationService {
  DriverLocationService._();
  static final instance = DriverLocationService._();

  final _controller = StreamController<LatLngPoint>.broadcast();
  Stream<LatLngPoint> get stream => _controller.stream;

  Timer? _timer;
  LatLngPoint _pos = const LatLngPoint(39.7392, -104.9903); // Denver

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      // Jitter position slightly to simulate movement.
      _pos = LatLngPoint(_pos.lat + 0.0003, _pos.lng + 0.00025);
      _controller.add(_pos);
    });
  }

  LatLngPoint get current => _pos;

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
