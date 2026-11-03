// File: rapidrun_driver/lib/widgets/navigation/turn_by_turn_hud_banner.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class TurnByTurnHudBanner extends StatelessWidget {
  final String instruction;
  final String distanceRemaining;
  final IconData maneuverIcon;

  const TurnByTurnHudBanner({
    super.key,
    this.instruction = 'Turn right on White Settlement Rd',
    this.distanceRemaining = '450 ft',
    this.maneuverIcon = Icons.turn_right_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14171D), // Obsidian Dark
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5A93C),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(maneuverIcon, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        distanceRemaining.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        instruction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
