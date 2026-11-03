import 'dart:async';
import 'package:rapidrun_shared/rapidrun_shared.dart';

/// Mock service that simulates streaming available orders to claim.
class OrderOfferService {
  OrderOfferService._();
  static final instance = OrderOfferService._();

  final _controller = StreamController<List<Order>>.broadcast();
  Stream<List<Order>> get offersStream => _controller.stream;

  Timer? _timer;
  final List<Order> _offers = [];
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    // Seed with a couple of faux orders
    _offers.addAll(_generateSeed());
    _emit();
    // Periodically add a new offer (stub logic)
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      _offers.add(_generateRandom());
      _emit();
    });
  }

  Future<bool> claim(String id) async {
    // In real implementation this would run a Firestore transaction ensuring driverId is null.
    final idx = _offers.indexWhere((o) => o.id == id);
    if (idx == -1) return false;
    _offers.removeAt(idx);
    _emit();
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  void _emit() => _controller.add(List.unmodifiable(_offers));

  List<Order> _generateSeed() => [
    Order(
      id: 'seed-1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      status: OrderStatus.pending,
      items: const [
        OrderLineItem(
          productId: 'a',
          name: 'Apples',
          unitPrice: 2.99,
          quantity: 3,
        ),
        OrderLineItem(
          productId: 'b',
          name: 'Yogurt',
          unitPrice: 1.29,
          quantity: 4,
        ),
      ],
      subtotal: 2.99 * 3 + 1.29 * 4,
      tax: 1.12,
      total: 2.99 * 3 + 1.29 * 4 + 1.12,
      payment: const OrderSummaryPayment(
        methodId: 'pm_1',
        brand: 'VISA',
        last4: '4242',
      ),
      address: const OrderSummaryAddress(
        id: 'addrA',
        line1: '55 Center Plz',
        city: 'Boston',
        state: 'MA',
        postalCode: '02108',
        fullName: 'Alice Example',
      ),
    ),
    Order(
      id: 'seed-2',
      createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      status: OrderStatus.pending,
      items: const [
        OrderLineItem(
          productId: 'c',
          name: 'Chicken Breast',
          unitPrice: 7.49,
          quantity: 1,
        ),
        OrderLineItem(
          productId: 'd',
          name: 'Spinach',
          unitPrice: 2.50,
          quantity: 2,
        ),
      ],
      subtotal: 7.49 + 2.50 * 2,
      tax: 0.98,
      total: 7.49 + 2.50 * 2 + 0.98,
      payment: const OrderSummaryPayment(
        methodId: 'pm_2',
        brand: 'MC',
        last4: '5555',
      ),
      address: const OrderSummaryAddress(
        id: 'addrB',
        line1: '1024 Elm St',
        city: 'Denver',
        state: 'CO',
        postalCode: '80205',
        fullName: 'Bob Example',
      ),
    ),
  ];

  Order _generateRandom() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return Order(
      id: 'offer-$ts',
      createdAt: DateTime.now(),
      status: OrderStatus.pending,
      items: const [
        OrderLineItem(
          productId: 'z',
          name: 'Bananas',
          unitPrice: 1.10,
          quantity: 6,
        ),
      ],
      subtotal: 1.10 * 6,
      tax: 0.42,
      total: 1.10 * 6 + 0.42,
      payment: const OrderSummaryPayment(
        methodId: 'pm_rand',
        brand: 'VISA',
        last4: '4242',
      ),
      address: const OrderSummaryAddress(
        id: 'addrRand',
        line1: '500 Random Rd',
        city: 'Austin',
        state: 'TX',
        postalCode: '73301',
        fullName: 'Random Customer',
      ),
    );
  }
}
