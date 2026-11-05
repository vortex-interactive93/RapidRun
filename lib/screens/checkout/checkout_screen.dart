// File: lib/screens/checkout/checkout_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../services/favorites_cart_service.dart';
import '../order/order_tracking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final String storeName;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    this.storeName = 'Bath & Body Works',
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  double _selectedTip = 5.00;
  bool _isSubmitting = false;

  final String _customerName = 'Thomas Davis';
  final double _customerLat = 32.759602;
  final double _customerLng = -97.471416;

  String get _customerAddress => customerState.address;
  String get _gateCode => customerState.gateCode;

  double get _deliveryFee => customerState.calculateDeliveryFee(widget.subtotal);
  double get _serviceFee => customerState.calculateServiceFee(widget.subtotal);
  double get _standardServiceFee => double.parse((widget.subtotal * 0.05).toStringAsFixed(2));
  double get _tax => widget.subtotal * 0.0825; // Texas 8.25%
  double get _total => widget.subtotal + _deliveryFee + _serviceFee + _tax + _selectedTip;

  Future<void> _placeOrder() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uniqueTimestamp = DateTime.now().millisecondsSinceEpoch;
      final orderId = 'ORD-${uniqueTimestamp.toString().substring(5)}';

      const double totalMiles = 3.8;
      const double activeSurgeBonus = 2.50; // Active surge radar bonus
      final int itemCount = widget.cartItems.fold<int>(0, (sum, i) => sum + ((i['quantity'] as num?)?.toInt() ?? 1));

      final payoutBreakdown = DispatchPricingEngine.calculateDriverPayout(
        estimatedDistanceMiles: totalMiles,
        totalItemCount: itemCount,
        basketSubtotal: widget.subtotal,
        activeSurgeBonus: activeSurgeBonus,
        customerTip: _selectedTip,
      );

      // 1. Construct authentic Firestore dispatch order
      final orderPayload = {
        'id': orderId,
        'customerId': user?.uid ?? 'cust_thomas_davis',
        'customerName': _customerName,
        'customerPhone': '+18175550198',
        'customerAddress': _customerAddress,
        'customerLat': _customerLat,
        'customerLng': _customerLng,
        'deliveryNotes': 'Gate code: $_gateCode. Leave at front door.',
        'storeId': 'store_bbw_westover',
        'storeName': widget.storeName,
        'storeAddress': 'Westover Village, Fort Worth, TX',
        'storeLat': 32.7485,
        'storeLng': -97.4261,
        'subtotal': widget.subtotal,
        'deliveryFee': _deliveryFee,
        'estimatedTax': _tax,
        'customerTip': _selectedTip,
        'guaranteedPayout': payoutBreakdown.totalPayout,
        'payoutBreakdown': payoutBreakdown.toMap(),
        'totalMiles': totalMiles,
        'itemCount': itemCount,
        'items': widget.cartItems,
        'status': 'pendingDispatch',
        'createdAt': FieldValue.serverTimestamp(),
        'driverId': null,
      };

      // 2. Commit to Firestore (triggers zero-index driver dispatch listener)
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set(orderPayload);

      // Clear local storage and reactive cart state immediately upon checkout
      await cartState.clearCart();
      await CartService.instance.clear();

      if (!mounted) return;

      // 3. Seamless transition directly to Live Order Tracking Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to dispatch order: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const bg = Color(0xFF101216);
    const cardBg = Color(0xFF171A21);

    return ListenableBuilder(
      listenable: customerState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Review & Concierge Checkout',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 1. Delivery Node Card (Pre-Populated)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.location_on_rounded, color: gold, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'DELIVERY DESTINATION',
                              style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2B2012), Color(0xFF140F08)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: gold,
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded, color: gold, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                customerState.tierName.toUpperCase(),
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(_customerAddress, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Text('Gate Code: $_gateCode • Leave at front door', style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Order Manifest Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.storeName.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('${widget.cartItems.length} items', style: const TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...widget.cartItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item['quantity']}x  ${item['name']}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '\$${(((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1)).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Courier Tip Selector (Dual-Touchpoint)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('PERSONAL COURIER TIP', style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        Text('100% goes to driver', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [3.00, 5.00, 8.00, 10.00].map((tipVal) {
                        final isSelected = _selectedTip == tipVal;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text('\$${tipVal.toInt()}', style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                              selected: isSelected,
                              selectedColor: gold,
                              backgroundColor: const Color(0xFF222631),
                              onSelected: (val) {
                                if (val) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedTip = tipVal);
                                }
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Financial Cost Matrix
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    _priceRow('Subtotal', widget.subtotal),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Concierge Delivery Fee', style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                        _deliveryFee == 0.0
                            ? Row(
                                children: [
                                  const Text('\$3.99', style: TextStyle(color: Colors.white38, fontSize: 12.5, decoration: TextDecoration.lineThrough)),
                                  const SizedBox(width: 6),
                                  Text('FREE (${customerState.tierName})', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 12.5)),
                                ],
                              )
                            : Text('\$${_deliveryFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Platform Service Fee', style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                        customerState.tier == MembershipTier.noirVip
                            ? Row(
                                children: [
                                  Text('\$${_standardServiceFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white38, fontSize: 12.5, decoration: TextDecoration.lineThrough)),
                                  const SizedBox(width: 6),
                                  const Text('FREE (Noir VIP)', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 12.5)),
                                ],
                              )
                            : customerState.tier == MembershipTier.velocity
                                ? Row(
                                    children: [
                                      Text('\$${_standardServiceFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white38, fontSize: 12.5, decoration: TextDecoration.lineThrough)),
                                      const SizedBox(width: 6),
                                      Text('\$${_serviceFee.toStringAsFixed(2)} (2.5% Pass)', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 12.5)),
                                    ],
                                  )
                                : Text('\$${_serviceFee.toStringAsFixed(2)} (5%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _priceRow('Estimated Sales Tax (8.25%)', _tax),
                    const SizedBox(height: 6),
                    _priceRow('Courier Tip', _selectedTip, isHighlight: true),
                    const Divider(color: Colors.white10, height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Authorization Hold', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 19)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : Text(
                        'PLACE ORDER • \$${_total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, letterSpacing: 0.6),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _priceRow(String label, double amount, {bool isHighlight = false}) {
    const gold = Color(0xFFE6B450);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isHighlight ? gold : Colors.white60, fontSize: 12.5)),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(color: isHighlight ? gold : Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
      ],
    );
  }
}
