import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart' as shared;

/// Simple utility to insert a synthetic pending order into Firestore for driver testing.
/// Usage:
/// dart run tool/create_test_order.dart --customer=demoUser123
/// Optional flags:
///   --items=3 (rough count of random line items)
///   --prefix=dev (order id prefix)
Future<void> main(List<String> args) async {
  final params = _Args.parse(args);
  if (params.customerId == null) {
    /* ignore: avoid_print */
    print('Missing --customer=customerId');
    return;
  }
  final fs = FirebaseFirestore.instance;
  final rand = Random();
  final itemCount = params.items;
  final now = DateTime.now();
  final orderId = '${params.prefix}-${now.millisecondsSinceEpoch}';
  final items = List.generate(itemCount, (i) {
    final qty = rand.nextInt(3) + 1;
    final price = (rand.nextDouble() * 8) + 1.25;
    return shared.OrderLineItem(
      productId: 'p$i',
      name: 'Test Item ${i + 1}',
      unitPrice: double.parse(price.toStringAsFixed(2)),
      quantity: qty,
    );
  });
  final subtotal = items.fold<double>(0, (s, e) => s + e.lineTotal);
  final tax = double.parse((subtotal * 0.0825).toStringAsFixed(2));
  final total = subtotal + tax;
  final order = shared.Order(
    id: orderId,
    createdAt: now,
    status: shared.OrderStatus.pending,
    items: items,
    subtotal: double.parse(subtotal.toStringAsFixed(2)),
    tax: tax,
    total: double.parse(total.toStringAsFixed(2)),
    payment: const shared.OrderSummaryPayment(
      methodId: 'pm_test',
      brand: 'VISA',
      last4: '4242',
    ),
    address: const shared.OrderSummaryAddress(
      id: 'addr_test',
      line1: '123 Test Loop',
      city: 'Austin',
      state: 'TX',
      postalCode: '73301',
      fullName: 'Test Customer',
    ),
  );

  final data = order.toJson();
  // Example collection path assumption. Adjust if your data model differs.
  final ref = fs.collection('orders').doc(order.id);
  await ref.set(data);
  /* ignore: avoid_print */
  print(
    'Created test order ${order.id} subtotal=${order.subtotal} total=${order.total}',
  );
}

class _Args {
  final String? customerId;
  final int items;
  final String prefix;
  _Args({this.customerId, required this.items, required this.prefix});
  static _Args parse(List<String> args) {
    String? customer;
    int items = 3;
    String prefix = 'test';
    for (final a in args) {
      if (a.startsWith('--customer=')) customer = a.split('=')[1];
      if (a.startsWith('--items=')) items = int.tryParse(a.split('=')[1]) ?? 3;
      if (a.startsWith('--prefix=')) prefix = a.split('=')[1];
    }
    return _Args(customerId: customer, items: items, prefix: prefix);
  }
}
