// File: lib/widgets/orders/order_adjustment_banner.dart

import 'package:flutter/material.dart';

class OrderAdjustmentBanner extends StatelessWidget {
  final double originalTotal;
  final double adjustedTotal;
  final int refundedItemsCount;

  const OrderAdjustmentBanner({
    super.key,
    required this.originalTotal,
    required this.adjustedTotal,
    required this.refundedItemsCount,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    final difference = originalTotal - adjustedTotal;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B241B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.greenAccent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Total Adjusted',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$refundedItemsCount items were unavailable and out of stock. We adjusted your total down by \$${difference.toStringAsFixed(2)}. You were only charged for what was picked!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Final Charge: \$${adjustedTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Was \$${originalTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11.5,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
