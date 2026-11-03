import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/orders_service.dart';
import '../models/order.dart';

final ordersProvider = ChangeNotifierProvider<OrdersService>((ref) {
  final svc = OrdersService.instance;
  svc.bootstrap();
  return svc;
});

List<Order> usePendingOrders(WidgetRef ref) {
  final svc = ref.watch(ordersProvider);
  return svc.orders
      .where((o) => o.status.name == 'pending' || o.status.name == 'assigned')
      .toList();
}
