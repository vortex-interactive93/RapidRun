// File: lib/widgets/catalog/independent_retailer_disclaimer.dart

import 'package:flutter/material.dart';

class IndependentRetailerDisclaimer extends StatelessWidget {
  const IndependentRetailerDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: gold.withValues(alpha: 0.8), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'RapidRun is an independent personal shopping and concierge delivery service. '
              'Product names, trademarks, and brand assets are the property of their respective owners '
              'and do not imply endorsement, affiliation, or direct partnership.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
