import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/card_brand.dart';
import '../../widgets/shimmer_box.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../services/favorites_cart_service.dart';
import '../../services/product_catalog_service.dart';
import '../../services/address_book_service.dart';
import '../../services/payment_methods_service.dart';
import '../../services/orders_service.dart';
import '../../services/order_dispatch_service.dart';
import '../../services/analytics_service.dart';
import '../../analytics/event_names.dart';
import '../../models/order.dart';
import '../../services/firebase_service.dart';
import '../../models/address.dart';
import '../../models/payment_method.dart';

/// Checkout gate: Summary -> Address -> Payment tabs. Requires auth to place order.
class CheckoutGateScreen extends StatefulWidget {
  const CheckoutGateScreen({super.key});
  @override
  State<CheckoutGateScreen> createState() => _CheckoutGateScreenState();
}

class _CheckoutGateScreenState extends State<CheckoutGateScreen> {
  final cart = CartService.instance;
  bool _loadingCatalog = false;
  double _subtotal = 0;
  int _tabIndex = 0; // 0 summary, 1 address, 2 payment

  @override
  void initState() {
    super.initState();
    cart.addListener(_recompute);
    _ensureCatalog();
    _recompute();
    _restoreTab();
  }

  @override
  void dispose() {
    cart.removeListener(_recompute);
    super.dispose();
  }

  Future<void> _ensureCatalog() async {
    if (_loadingCatalog) return;
    _loadingCatalog = true;
    await ProductCatalogService.instance.ensureLoaded();
    if (!mounted) return;
    _loadingCatalog = false;
    _recompute();
  }

  void _recompute() {
    double total = 0;
    cart.items.forEach((id, qty) {
      final p = ProductCatalogService.instance.get(id);
      if (p?.price != null) total += p!.price! * qty;
    });
    setState(() => _subtotal = total);
  }

  Future<void> _restoreTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt('checkout_tab_v1');
      if (idx != null && mounted) setState(() => _tabIndex = idx.clamp(0, 2));
    } catch (_) {}
  }

  Future<void> _persistTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('checkout_tab_v1', _tabIndex);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.user;
    final entries = cart.items.entries.toList();
    final isEmpty = entries.isEmpty;
    const gold = Color(0xFFE6B450);
    return Scaffold(
      backgroundColor: const Color(0xFF1f1f1f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        iconTheme: const IconThemeData(color: gold),
        title: const Text(
          'Checkout',
          style: TextStyle(color: gold, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isEmpty)
              const _EmptyCartNotice()
            else ...[
              _TabHeader(
                index: _tabIndex,
                onChanged: (i) {
                  setState(() => _tabIndex = i);
                  _persistTab();
                },
              ),
              const SizedBox(height: 12),
              if (_tabIndex == 0) ...[
                _CartSummary(subtotal: _subtotal, loading: _loadingCatalog),
                const SizedBox(height: 18),
                Expanded(child: _LineItemsList(entries: entries)),
              ] else if (_tabIndex == 1) ...[
                Expanded(child: _AddressBookPanel()),
              ] else ...[
                Expanded(child: _PaymentMethodsPanel()),
              ],
            ],
            const SizedBox(height: 12),
            if (!isEmpty)
              user == null
                  ? ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In to Continue'),
                    )
                  : ElevatedButton(
                      onPressed: () => _goToReview(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Place Order (Demo)'),
                    ),
          ],
        ),
      ),
    );
  }

  void _goToReview(BuildContext context) {
    AnalyticsService.instance.log(AppEvent.checkoutReviewOpen);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _OrderReviewScreen()),
    );
  }
}

class _OrderReviewScreen extends StatefulWidget {
  const _OrderReviewScreen();
  @override
  State<_OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<_OrderReviewScreen> {
  Address? _selectedAddress;
  PaymentMethodSummary? _selectedPayment;
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Preselect defaults
    final addrSvc = AddressBookService.instance;
    final paySvc = PaymentMethodsService.instance;
    if (addrSvc.all.isNotEmpty) {
      _selectedAddress = addrSvc.all.firstWhere(
        (a) => a.isDefault,
        orElse: () => addrSvc.all.first,
      );
    }
    if (paySvc.all.isNotEmpty) {
      _selectedPayment = paySvc.all.firstWhere(
        (p) => p.isDefault,
        orElse: () => paySvc.all.first,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance.items;
    final entries = cart.entries.toList();
    final catalog = ProductCatalogService.instance;
    double subtotal = 0;
    final lines = entries.map((e) {
      final prod = catalog.get(e.key);
      final price = prod?.price ?? 0;
      subtotal += price * e.value;
      return {'name': prod?.name ?? e.key, 'qty': e.value, 'price': price};
    }).toList();
    final tax = double.parse((subtotal * 0.07).toStringAsFixed(2));
    final total = subtotal + tax;
    const gold = Color(0xFFE6B450);
    return Scaffold(
      backgroundColor: const Color(0xFF1f1f1f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        iconTheme: const IconThemeData(color: gold),
        title: const Text('Review & Place', style: TextStyle(color: gold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _sectionCard(
              title: 'Items',
              child: Column(
                children: [
                  for (final l in lines)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l['name'] as String,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        Text(
                          'x${l['qty']}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          NumberFormat.simpleCurrency().format(l['price']),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Shipping Address',
              action: TextButton(
                onPressed: _chooseAddress,
                child: const Text('Change'),
              ),
              child: _selectedAddress == null
                  ? const Text(
                      'No address selected',
                      style: TextStyle(color: Colors.white54),
                    )
                  : Text(
                      [
                        _selectedAddress!.fullName,
                        _selectedAddress!.line1,
                        if (_selectedAddress!.line2?.isNotEmpty == true)
                          _selectedAddress!.line2,
                        '${_selectedAddress!.city}, ${_selectedAddress!.state} ${_selectedAddress!.postalCode}',
                      ].whereType<String>().join('\n'),
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.25,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Payment',
              action: TextButton(
                onPressed: _choosePayment,
                child: const Text('Change'),
              ),
              child: _selectedPayment == null
                  ? const Text(
                      'No payment selected',
                      style: TextStyle(color: Colors.white54),
                    )
                  : Text(
                      '${_selectedPayment!.brand} •••• ${_selectedPayment!.last4}\nExp ${_selectedPayment!.expMonth.toString().padLeft(2, '0')}/${_selectedPayment!.expYear % 100}',
                      style: const TextStyle(color: Colors.white70),
                    ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Totals',
              child: Column(
                children: [
                  _totRow('Subtotal', subtotal),
                  _totRow('Tax (7%)', tax),
                  const Divider(color: Colors.white24),
                  _totRow('Total', total, bold: true),
                ],
              ),
            ),
            const Spacer(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _placing ? null : () => _place(total, subtotal, tax),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _placing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Place Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totRow(String label, double amount, {bool bold = false}) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      Text(
        NumberFormat.simpleCurrency().format(amount),
        style: TextStyle(
          color: Colors.white70,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ],
  );

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? action,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF222222),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFE6B450).withValues(alpha: 0.25),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (action != null) action,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Future<void> _chooseAddress() async {
    final svc = AddressBookService.instance;
    if (svc.all.isEmpty) return;
    final sel = await showModalBottomSheet<Address>(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final a in svc.all)
            ListTile(
              title: Text(
                a.fullName,
                style: const TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                a.line1,
                style: const TextStyle(color: Colors.white38),
              ),
              onTap: () => Navigator.pop(context, a),
              trailing: a.id == _selectedAddress?.id
                  ? const Icon(Icons.check, color: Color(0xFFE6B450))
                  : null,
            ),
        ],
      ),
    );
    if (sel != null) setState(() => _selectedAddress = sel);
  }

  Future<void> _choosePayment() async {
    final svc = PaymentMethodsService.instance;
    if (svc.all.isEmpty) return;
    final sel = await showModalBottomSheet<PaymentMethodSummary>(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final p in svc.all)
            ListTile(
              title: Text(
                '${p.brand} •••• ${p.last4}',
                style: const TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                'Exp ${p.expMonth.toString().padLeft(2, '0')}/${p.expYear % 100}',
                style: const TextStyle(color: Colors.white38),
              ),
              onTap: () => Navigator.pop(context, p),
              trailing: p.id == _selectedPayment?.id
                  ? const Icon(Icons.check, color: Color(0xFFE6B450))
                  : null,
            ),
        ],
      ),
    );
    if (sel != null) setState(() => _selectedPayment = sel);
  }

  Future<void> _place(double total, double subtotal, double tax) async {
    if (_placing) return; // idempotency guard
    if (_selectedAddress == null) {
      setState(() => _error = 'Select address');
      return;
    }
    if (_selectedPayment == null) {
      setState(() => _error = 'Select payment');
      return;
    }
    setState(() {
      _error = null;
      _placing = true;
    });
    try {
      AnalyticsService.instance.log(
        AppEvent.orderPlaceAttempt,
        props: {
          'items': CartService.instance.totalItems,
          'subtotal': subtotal,
          'tax': tax,
          'total': total,
        },
      );
      final order = await OrdersService.instance.placeOrder(
        address: _selectedAddress!,
        payment: _selectedPayment!,
      );

      // Dispatch live order to Cloud Firestore for driver app pickup!
      try {
        final cartEntries = CartService.instance.items.entries.toList();
        final catalog = ProductCatalogService.instance;
        final liveItems = cartEntries.map((e) {
          final prod = catalog.get(e.key);
          return {
            'id': prod?.id ?? e.key,
            'name': prod?.name ?? 'Bath & Body Works Item',
            'quantity': e.value,
            'price': prod?.price ?? 16.95,
            'imageUrl': prod?.imageUrl ?? '',
            'unit': prod?.unitShort ?? prod?.unit ?? 'Standard',
          };
        }).toList();

        await OrderDispatchService.instance.submitLiveOrder(
          items: liveItems,
          customerAddress: [
            _selectedAddress!.line1,
            if (_selectedAddress!.line2?.isNotEmpty == true) _selectedAddress!.line2,
            '${_selectedAddress!.city}, ${_selectedAddress!.state} ${_selectedAddress!.postalCode}',
          ].whereType<String>().join(', '),
          customerName: _selectedAddress!.fullName,
        );
      } catch (dispatchErr) {
        debugPrint('[CheckoutGate] Real-time dispatch warning: $dispatchErr');
      }

      AnalyticsService.instance.log(
        AppEvent.orderPlaceSuccess,
        props: {
          'orderId': order.id,
          'total': order.total,
          'lines': order.items.length,
        },
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _OrderConfirmationScreen(order: order),
        ),
      );
    } catch (e) {
      AnalyticsService.instance.log(
        AppEvent.orderPlaceFail,
        props: {'error': e.toString()},
      );
      setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}

class _OrderConfirmationScreen extends StatelessWidget {
  final Order order;
  const _OrderConfirmationScreen({required this.order});
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    return Scaffold(
      backgroundColor: const Color(0xFF1f1f1f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        iconTheme: const IconThemeData(color: gold),
        title: const Text('Order Placed', style: TextStyle(color: gold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: gold, size: 72),
              const SizedBox(height: 16),
              Text(
                'Order #${order.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Total ${NumberFormat.simpleCurrency().format(order.total)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabHeader extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _TabHeader({required this.index, required this.onChanged});
  static const _labels = ['Summary', 'Address', 'Payment'];
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: i == index
                      ? const Color(0xFFE6B450).withValues(alpha: 0.15)
                      : const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: i == index
                        ? const Color(0xFFE6B450)
                        : const Color(0xFFE6B450).withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      color: const Color(0xFFE6B450),
                      fontWeight: i == index
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LineItemsList extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _LineItemsList({required this.entries});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
      itemBuilder: (ctx, i) {
        final e = entries[i];
        final prod = ProductCatalogService.instance.get(e.key);
        return Row(
          children: [
            Expanded(
              child: Text(
                prod?.name ?? e.key,
                style: const TextStyle(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('x${e.value}', style: const TextStyle(color: Colors.white54)),
          ],
        );
      },
    );
  }
}

class _AddressBookPanel extends StatefulWidget {
  @override
  State<_AddressBookPanel> createState() => _AddressBookPanelState();
}

class _AddressBookPanelState extends State<_AddressBookPanel> {
  final _svc = AddressBookService.instance;
  bool _bootstrapped = false;
  @override
  void initState() {
    super.initState();
    _ensure();
    _svc.addListener(_listener);
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  Future<void> _ensure() async {
    await _svc.bootstrap();
    if (mounted) setState(() => _bootstrapped = true);
  }

  @override
  void dispose() {
    _svc.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _svc.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Addresses',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Icons.add_location_alt,
                color: Color(0xFFE6B450),
              ),
              tooltip: 'Add address',
              onPressed: () => _openEditor(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_bootstrapped)
          Expanded(
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const _AddressSkeleton(),
            ),
          )
        else if (list.isEmpty)
          const Text(
            'No addresses yet',
            style: TextStyle(color: Colors.white38),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (c, i) {
                final a = list[i];
                return Dismissible(
                  key: ValueKey(a.id),
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.startToEnd,
                  onDismissed: (_) => _svc.remove(a.id),
                  child: InkWell(
                    onTap: () => _openEditor(existing: a),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(
                            0xFFE6B450,
                          ).withValues(alpha: a.isDefault ? 0.8 : 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (a.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE6B450,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      color: Color(0xFFE6B450),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              a.line1,
                              if (a.line2?.isNotEmpty == true) a.line2,
                              '${a.city}, ${a.state} ${a.postalCode}',
                            ].whereType<String>().join('\n'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _openEditor({Address? existing}) async {
    final res = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddressEditor(existing: existing),
      ),
    );
    if (res != null) {
      await _svc.upsert(res);
    }
  }
}

class _AddressEditor extends StatefulWidget {
  final Address? existing;
  const _AddressEditor({this.existing});
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.fullName);
  late final _l1 = TextEditingController(text: widget.existing?.line1);
  late final _l2 = TextEditingController(text: widget.existing?.line2);
  late final _city = TextEditingController(text: widget.existing?.city);
  late final _state = TextEditingController(text: widget.existing?.state);
  late final _zip = TextEditingController(text: widget.existing?.postalCode);
  late bool _isDefault;
  @override
  void initState() {
    super.initState();
    _isDefault = widget.existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _l1.dispose();
    _l2.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null ? 'Add Address' : 'Edit Address',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _field(_name, 'Full Name'),
            const SizedBox(height: 10),
            _field(_l1, 'Line 1'),
            const SizedBox(height: 10),
            _field(_l2, 'Line 2 (optional)', required: false),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _field(_city, 'City')),
                const SizedBox(width: 10),
                SizedBox(width: 90, child: _field(_state, 'State')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _field(_zip, 'ZIP')),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Switch(
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      activeColor: gold,
                    ),
                    const Text(
                      'Default',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  final addr = Address(
                    id: widget.existing?.id ?? const Uuid().v4(),
                    fullName: _name.text.trim(),
                    line1: _l1.text.trim(),
                    line2: _l2.text.trim().isEmpty ? null : _l2.text.trim(),
                    city: _city.text.trim(),
                    state: _state.text.trim(),
                    postalCode: _zip.text.trim(),
                    isDefault: _isDefault,
                  );
                  Navigator.pop(context, addr);
                },
                child: Text(
                  widget.existing == null ? 'Save Address' : 'Update Address',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = true,
  }) => TextFormField(
    controller: c,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF262626),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE6B450)),
      ),
    ),
    style: const TextStyle(color: Colors.white, fontSize: 13),
    validator: (v) {
      if (!required) return null;
      if (v == null || v.trim().isEmpty) return 'Required';
      return null;
    },
  );
}

class _PaymentMethodsPanel extends StatefulWidget {
  @override
  State<_PaymentMethodsPanel> createState() => _PaymentMethodsPanelState();
}

class _PaymentMethodsPanelState extends State<_PaymentMethodsPanel> {
  final _svc = PaymentMethodsService.instance;
  bool _bootstrapped = false;
  @override
  void initState() {
    super.initState();
    _ensure();
    _svc.addListener(_listener);
  }

  void _listener() => mounted ? setState(() => {}) : null;
  Future<void> _ensure() async {
    await _svc.bootstrap();
    if (mounted) setState(() => _bootstrapped = true);
  }

  @override
  void dispose() {
    _svc.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _svc.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Payment Methods',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_card, color: Color(0xFFE6B450)),
              tooltip: 'Add card',
              onPressed: () => _openAdd(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_bootstrapped)
          Expanded(
            child: ListView.separated(
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const _PaymentSkeleton(),
            ),
          )
        else if (list.isEmpty)
          const Text(
            'No payment methods yet',
            style: TextStyle(color: Colors.white38),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (c, i) {
                final pm = list[i];
                return Dismissible(
                  key: ValueKey(pm.id),
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.startToEnd,
                  onDismissed: (_) => _svc.remove(pm.id),
                  child: InkWell(
                    onTap: () => _openAdd(existing: pm),
                    onLongPress: () => _toggleDefault(pm),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(
                            0xFFE6B450,
                          ).withValues(alpha: pm.isDefault ? 0.8 : 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          _CardBrandIcon(
                            number: pm.last4,
                            brandLabel: pm.brand,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pm.brand} •••• ${pm.last4}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Exp ${pm.expMonth.toString().padLeft(2, '0')}/${pm.expYear % 100}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (pm.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE6B450,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  color: Color(0xFFE6B450),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _toggleDefault(PaymentMethodSummary pm) {
    _svc.upsert(pm.copyWith(isDefault: true));
  }

  Future<void> _openAdd({PaymentMethodSummary? existing}) async {
    final res = await showModalBottomSheet<PaymentMethodSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddCardSheet(existing: existing),
      ),
    );
    if (res != null) {
      await _svc.upsert(res);
    }
  }
}

class _AddCardSheet extends StatefulWidget {
  final PaymentMethodSummary? existing;
  const _AddCardSheet({this.existing});
  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _exp;
  late final TextEditingController _cvc;
  bool _default = false;
  bool _saving = false;
  CardBrand _brand = CardBrand.unknown;
  @override
  void initState() {
    super.initState();
    _number = TextEditingController();
    _exp = TextEditingController();
    _cvc = TextEditingController();
    final existing = widget.existing;
    if (existing != null) {
      _number.text = '•••• ${existing.last4}';
      _exp.text =
          '${existing.expMonth.toString().padLeft(2, '0')}/${(existing.expYear % 100).toString().padLeft(2, '0')}';
      _default = existing.isDefault;
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _exp.dispose();
    _cvc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    final editing = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              editing ? 'Edit Card' : 'Add Card',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _cardNumberField(),
            _brandHint(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _expiryField()),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _cvc,
                    'CVC',
                    validator: CardValidator.validateCvc,
                    keyboard: TextInputType.number,
                    maxLen: 4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _default,
                  onChanged: (v) => setState(() => _default = v),
                  activeColor: gold,
                ),
                const Text('Default', style: TextStyle(color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(editing ? 'Update Card' : 'Save Card'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardNumberField() => TextFormField(
    controller: _number,
    keyboardType: TextInputType.number,
    validator: (v) {
      if (widget.existing != null && (v ?? '').startsWith('••••')) return null;
      return CardValidator.validateNumber(v);
    },
    onChanged: (v) {
      if (widget.existing != null && v.startsWith('••••')) return;
      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
      final grouped = <String>[];
      for (int i = 0; i < digits.length; i += 4) {
        grouped.add(
          digits.substring(i, i + 4 > digits.length ? digits.length : i + 4),
        );
      }
      final nt = grouped.join(' ');
      if (nt != v) {
        _number.value = TextEditingValue(
          text: nt,
          selection: TextSelection.collapsed(offset: nt.length),
        );
      }
      setState(() => _brand = detectCardBrand(digits));
    },
    decoration: _dec('Card Number'),
    style: const TextStyle(color: Colors.white, fontSize: 13),
  );
  Widget _brandHint() {
    if (_brand == CardBrand.unknown) return const SizedBox.shrink();
    final style = cardBrandStyle(_brand);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: style.gradient == null ? style.color : null,
          gradient: style.gradient,
        ),
        child: Text(
          cardBrandLabel(_brand).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _expiryField() => TextFormField(
    controller: _exp,
    keyboardType: TextInputType.number,
    validator: CardValidator.validateExpiry,
    onChanged: (v) {
      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
      String out = digits;
      if (digits.length > 2) {
        out =
            digits.substring(0, 2) +
            '/' +
            digits.substring(2, digits.length > 4 ? 4 : digits.length);
      }
      if (out != v) {
        _exp.value = TextEditingValue(
          text: out,
          selection: TextSelection.collapsed(offset: out.length),
        );
      }
    },
    decoration: _dec('MM/YY'),
    style: const TextStyle(color: Colors.white, fontSize: 13),
    maxLength: 5,
    buildCounter:
        (_, {required currentLength, required isFocused, maxLength}) =>
            const SizedBox.shrink(),
  );
  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
    filled: true,
    fillColor: const Color(0xFF262626),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE6B450)),
    ),
  );
  Widget _field(
    TextEditingController c,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int? maxLen,
  }) => TextFormField(
    controller: c,
    validator: validator,
    keyboardType: keyboard,
    maxLength: maxLen,
    buildCounter: maxLen != null
        ? (_, {required currentLength, required isFocused, maxLength}) =>
              const SizedBox.shrink()
        : null,
    decoration: _dec(label),
    style: const TextStyle(color: Colors.white, fontSize: 13),
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 300));
    String numberRaw;
    if (widget.existing != null && _number.text.startsWith('••••')) {
      numberRaw = '0000${widget.existing!.last4}';
    } else {
      numberRaw = _number.text.replaceAll(RegExp(r'[^0-9]'), '');
    }
    final expParts = _exp.text.split('/');
    final month = int.tryParse(expParts[0]) ?? 1;
    final year =
        2000 + (int.tryParse(expParts.length > 1 ? expParts[1] : '') ?? 25);
    final last4 = numberRaw.substring(numberRaw.length - 4);
    final brand = _detectBrand(numberRaw);
    final pm = PaymentMethodSummary(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: PaymentMethodType.card,
      brand: brand,
      last4: last4,
      expMonth: month,
      expYear: year,
      isDefault: _default,
    );
    if (mounted) Navigator.pop(context, pm);
  }

  String _detectBrand(String num) {
    if (num.startsWith('4')) return 'Visa';
    if (RegExp(r'^(51|52|53|54|55)').hasMatch(num)) return 'MasterCard';
    if (RegExp(r'^(34|37)').hasMatch(num)) return 'AmEx';
    return 'Card';
  }
}

class _CardBrandIcon extends StatelessWidget {
  final String number; // may be last4 only
  final String brandLabel; // stored label
  const _CardBrandIcon({required this.number, required this.brandLabel});
  @override
  Widget build(BuildContext context) {
    final detected = detectCardBrand(number);
    final normalized = brandLabel.isNotEmpty
        ? brandLabel.toLowerCase()
        : cardBrandLabel(detected).toLowerCase();
    CardBrand brandEnum = detected;
    if (normalized.startsWith('visa'))
      brandEnum = CardBrand.visa;
    else if (normalized.startsWith('master'))
      brandEnum = CardBrand.mastercard;
    else if (normalized.startsWith('amex') || normalized.contains('american'))
      brandEnum = CardBrand.amex;
    else if (normalized.startsWith('discover'))
      brandEnum = CardBrand.discover;
    final style = cardBrandStyle(brandEnum);
    return Container(
      width: 44,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: style.gradient == null ? style.color : null,
        gradient: style.gradient,
      ),
      alignment: Alignment.center,
      child: Text(
        cardBrandLabel(brandEnum).toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _AddressSkeleton extends StatelessWidget {
  const _AddressSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(width: 140, height: 14),
          SizedBox(height: 8),
          ShimmerBox(width: 220, height: 10),
          SizedBox(height: 4),
          ShimmerBox(width: 180, height: 10),
        ],
      ),
    );
  }
}

class _PaymentSkeleton extends StatelessWidget {
  const _PaymentSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: const [
          ShimmerBox(width: 40, height: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 120, height: 12),
                SizedBox(height: 6),
                ShimmerBox(width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double subtotal;
  final bool loading;
  const _CartSummary({required this.subtotal, required this.loading});
  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.simpleCurrency();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6B450).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Color(0xFFE6B450)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'Calculating subtotal…'
                      : 'Subtotal: ${f.format(subtotal)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartNotice extends StatelessWidget {
  const _EmptyCartNotice();
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.remove_shopping_cart,
              color: Colors.white24,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your cart is empty',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Browse Products'),
            ),
          ],
        ),
      ),
    );
  }
}
