// File: lib/widgets/checkout/heavy_order_notice_tile.dart

import 'package:flutter/material.dart';

class HeavyOrderNoticeTile extends StatelessWidget {
  final double fee;
  final double totalWeightLbs;
  final String reason;

  const HeavyOrderNoticeTile({
    super.key,
    required this.fee,
    required this.totalWeightLbs,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF211A10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Heavy Order Surcharge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '+\$${fee.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$reason. 100% of this fee goes directly to your driver for lifting and handling bulky cargo.',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
