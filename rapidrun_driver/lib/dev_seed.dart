import 'package:cloud_firestore/cloud_firestore.dart';

/// Development helper to insert a sample pending order so the driver
/// app has something to display/claim. Do NOT ship enabled in prod.
Future<String> seedTestOrder({bool withSecondItem = false}) async {
  final col = FirebaseFirestore.instance.collection('orders');
  final doc = col.doc(); // auto id
  final serverTime = FieldValue.serverTimestamp();

  final items = [
    {'productId': 'p1', 'name': 'Sample Item', 'unitPrice': 5, 'quantity': 2},
  ];
  if (withSecondItem) {
    items.add({
      'productId': 'p2',
      'name': 'Extra Item',
      'unitPrice': 3.25,
      'quantity': 1,
    });
  }
  double subtotal = 0;
  for (final i in items) {
    subtotal += (i['unitPrice'] as num) * (i['quantity'] as num);
  }
  final tax = double.parse((subtotal * 0.08).toStringAsFixed(2));
  final total = double.parse((subtotal + tax).toStringAsFixed(2));

  await doc.set({
    'status': 'pending',
    'createdAt': serverTime,
    'subtotal': subtotal,
    'tax': tax,
    'total': total,
    'items': items,
    'payment': {'methodId': 'pm_test', 'brand': 'VISA', 'last4': '4242'},
    'address': {
      'id': 'addr1',
      'line1': '1 Test St',
      'city': 'City',
      'state': 'ST',
      'postalCode': '00000',
      'fullName': 'Tester User',
    },
    // Intentionally omit driverId so it's available
  });
  return doc.id;
}

/// Optional helper to quickly seed N orders.
Future<List<String>> seedMultiple(int count) async {
  final ids = <String>[];
  for (var i = 0; i < count; i++) {
    ids.add(await seedTestOrder(withSecondItem: i.isOdd));
  }
  return ids;
}
