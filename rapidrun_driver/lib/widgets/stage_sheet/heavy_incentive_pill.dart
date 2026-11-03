// File: rapidrun_driver/lib/widgets/stage_sheet/heavy_incentive_pill.dart

import 'package:flutter/material.dart';

class HeavyIncentivePill extends StatelessWidget {
  final double weightLbs;
  final double incentiveBonus;

  const HeavyIncentivePill({
    super.key,
    required this.weightLbs,
    required this.incentiveBonus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF33200B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fitness_center_rounded, color: Color(0xFFF59E0B), size: 14),
          const SizedBox(width: 6),
          Text(
            'HEAVY CARGO: ${weightLbs.round()} LBS (+\$${incentiveBonus.toStringAsFixed(2)} BONUS INCLUDED)',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
