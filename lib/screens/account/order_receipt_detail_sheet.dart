// File: lib/screens/account/order_receipt_detail_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

class OrderReceiptDetailSheet extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  final String orderId;
  final String storeName;
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double tip;
  final List<dynamic> items;

  const OrderReceiptDetailSheet({
    super.key,
    this.orderData,
    this.orderId = '46342444',
    this.storeName = 'Bath & Body Works',
    this.subtotal = 47.60,
    this.deliveryFee = 0.00, // Noir VIP Waived
    this.tax = 3.93,
    this.tip = 10.00,
    this.items = const [
      {'name': 'Amber Era Fine Fragrance Mist', 'qty': 8, 'price': 5.95},
    ],
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOrderId = (orderData?['orderId'] ?? orderId).toString();
    final effectiveStoreName = (orderData?['storeName'] ?? storeName).toString();
    final effectiveSubtotal = (orderData?['subtotal'] as num?)?.toDouble() ?? subtotal;
    final effectiveDeliveryFee = (orderData?['deliveryFee'] as num?)?.toDouble() ?? deliveryFee;
    final effectiveTax = (orderData?['tax'] as num?)?.toDouble() ?? tax;
    final effectiveTip = (orderData?['tip'] as num?)?.toDouble() ?? tip;
    final effectiveItems = (orderData?['items'] as List<dynamic>?) ?? items;

    final double total = effectiveSubtotal + effectiveDeliveryFee + effectiveTax + effectiveTip;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF14171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectiveStoreName.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Order #$effectiveOrderId',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),

          // Dynamic Items List
          if (effectiveItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No itemized data available.', style: TextStyle(color: Colors.white38)),
            )
          else
            ...effectiveItems.map((item) {
              final itemMap = item as Map<String, dynamic>;
              final qty = (itemMap['qty'] ?? itemMap['quantity'] ?? 1) as num;
              final name = (itemMap['name'] ?? 'Item').toString();
              final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${qty.toInt()}x $name',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\$${(price * qty).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),

          const Divider(color: Colors.white10, height: 28),

          // Payout Ledger Breakdown
          _buildRow('Subtotal', '\$${effectiveSubtotal.toStringAsFixed(2)}'),
          _buildRow('Concierge Delivery Fee', effectiveDeliveryFee == 0 ? 'FREE (Noir VIP)' : '\$${effectiveDeliveryFee.toStringAsFixed(2)}',
              valueColor: effectiveDeliveryFee == 0 ? const Color(0xFF34D399) : Colors.white),
          _buildRow('Texas Sales Tax (8.25%)', '\$${effectiveTax.toStringAsFixed(2)}'),
          _buildRow('Courier Tip (100% to Driver)', '\$${effectiveTip.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildRow('Total Paid', '\$${total.toStringAsFixed(2)}', isBold: true, valueColor: const Color(0xFFE5A93C)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A93C),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 3,
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              final List<CartItem> reorderItems = effectiveItems.map((item) {
                final itemMap = item as Map<String, dynamic>;
                return CartItem(
                  id: (itemMap['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
                  storeId: 'store_bbw_westover',
                  storeName: (itemMap['storeName'] ?? itemMap['brand'] ?? 'Bath & Body Works').toString(),
                  title: (itemMap['title'] ?? itemMap['name'] ?? 'Product').toString(),
                  subtitle: (itemMap['subtitle'] ?? itemMap['size'] ?? 'Regular').toString(),
                  price: (itemMap['price'] as num?)?.toDouble() ?? 9.99,
                  quantity: (itemMap['qty'] ?? itemMap['quantity'] ?? 1) as int,
                );
              }).toList();

              cartState.reorderBatch(reorderItems, forceClear: true);

              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚡ ${reorderItems.length} items re-added to your bag! Ready for checkout.'),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.replay_rounded, size: 20),
            label: const Text(
              'RE-ORDER ALL ITEMS IN 1-TAP',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE RECEIPT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white54, fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: isBold ? 16 : 13, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
        ],
      ),
    );
  }
}
