import 'package:flutter/material.dart';
import '../../services/preferences_service.dart';
import '../../services/payment_methods_service.dart';
import '../../models/payment_method.dart';

/// Payment Methods manager connected to PaymentMethodsService (shared with Checkout).
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});
  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _service = PaymentMethodsService.instance;
  double defaultTip = 0.15; // 15%

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChange);
    _service.bootstrap();
    _loadTip();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTip() async {
    defaultTip = await PreferencesService.getDefaultTip();
    if (mounted) setState(() {});
  }

  void _add() async {
    final method = await showDialog<PaymentMethodSummary>(
      context: context,
      builder: (_) => const _EditPaymentDialog(),
    );
    if (method != null) await _service.upsert(method);
  }

  void _edit(PaymentMethodSummary existing) async {
    final method = await showDialog<PaymentMethodSummary>(
      context: context,
      builder: (_) => _EditPaymentDialog(existing: existing),
    );
    if (method != null) await _service.upsert(method);
  }

  void _remove(String id) async {
    await _service.remove(id);
  }

  void _setDefault(PaymentMethodSummary m) async {
    await _service.upsert(m.copyWith(isDefault: true));
  }

  @override
  Widget build(BuildContext context) {
    final methods = _service.all;
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Payment Methods'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        onPressed: _add,
        child: const Icon(Icons.add_card),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: const Color(0xFF262626),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Default Driver Tip',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${(defaultTip * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFFFFC107),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: defaultTip,
                    min: 0,
                    max: 0.3,
                    divisions: 6,
                    activeColor: const Color(0xFFFFC107),
                    inactiveColor: Colors.white12,
                    onChanged: (v) => setState(() => defaultTip = v),
                    onChangeEnd: (v) => PreferencesService.setDefaultTip(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SAVED CARDS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (methods.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No saved payment methods. Tap + to add one.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            ...methods.map((m) {
              final isDefault = m.isDefault;
              return Card(
                color: const Color(0xFF262626),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDefault ? const Color(0xFFFFC107) : Colors.white10,
                    width: isDefault ? 1.4 : 0.8,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Icon(
                    isDefault ? Icons.credit_card : Icons.credit_card_outlined,
                    color: isDefault ? const Color(0xFFFFC107) : Colors.white54,
                  ),
                  title: Row(
                    children: [
                      Text(
                        '${m.brand.toUpperCase()} •••• ${m.last4}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              color: Color(0xFFFFC107),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'Expires ${m.expMonth}/${m.expYear}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    color: const Color(0xFF2A2A2A),
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          _edit(m);
                          break;
                        case 'delete':
                          _remove(m.id);
                          break;
                        case 'default':
                          _setDefault(m);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ),
                      if (!isDefault)
                        const PopupMenuItem(
                          value: 'default',
                          child: Text('Set Default', style: TextStyle(color: Color(0xFFFFC107))),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _EditPaymentDialog extends StatefulWidget {
  final PaymentMethodSummary? existing;
  const _EditPaymentDialog({this.existing});
  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  final _brand = TextEditingController();
  final _last4 = TextEditingController();
  final _expMonth = TextEditingController();
  final _expYear = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _brand.text = e.brand;
      _last4.text = e.last4;
      _expMonth.text = e.expMonth.toString();
      _expYear.text = e.expYear.toString();
    } else {
      _brand.text = 'Visa';
      _expMonth.text = '12';
      _expYear.text = '2028';
    }
  }

  @override
  void dispose() {
    _brand.dispose();
    _last4.dispose();
    _expMonth.dispose();
    _expYear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF262626),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.existing == null ? 'Add Payment Method' : 'Edit Card',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_brand, 'Brand (Visa, Mastercard, Amex)'),
            _field(_last4, 'Last 4 Digits', numeric: true, maxLength: 4),
            Row(
              children: [
                Expanded(child: _field(_expMonth, 'Exp Month', numeric: true)),
                const SizedBox(width: 8),
                Expanded(child: _field(_expYear, 'Exp Year', numeric: true)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (_brand.text.trim().isEmpty || _last4.text.trim().length != 4) return;
            final now = DateTime.now().millisecondsSinceEpoch.toString();
            final id = widget.existing?.id ?? 'pm_$now';
            Navigator.pop(
              context,
              PaymentMethodSummary(
                id: id,
                type: PaymentMethodType.card,
                brand: _brand.text.trim(),
                last4: _last4.text.trim(),
                expMonth: int.tryParse(_expMonth.text.trim()) ?? 12,
                expYear: int.tryParse(_expYear.text.trim()) ?? 2028,
                isDefault: widget.existing?.isDefault ?? false,
              ),
            );
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {bool numeric = false, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF1F1F1F),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFFC107)),
          ),
        ),
      ),
    );
  }
}
