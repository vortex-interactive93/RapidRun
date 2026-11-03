import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/driver_service.dart';
import '../models/driver.dart';

/// Exposes list of drivers (local only) and auto-updates listeners.
final driversProvider = ChangeNotifierProvider<DriverService>((ref) {
  final svc = DriverService.instance;
  svc.bootstrap();
  return svc;
});

DriverProfile? useDriver(WidgetRef ref, String id) {
  final svc = ref.watch(driversProvider);
  return svc.getById(id);
}
