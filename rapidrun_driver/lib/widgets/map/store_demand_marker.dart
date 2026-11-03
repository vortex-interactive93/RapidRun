// File: rapidrun_driver/lib/widgets/map/store_demand_marker.dart

import 'package:flutter/material.dart';

class StoreDemandMarker extends StatefulWidget {
  final String storeName;
  final double surgeBonus;
  final int activeBatches;
  final VoidCallback onTap;

  const StoreDemandMarker({
    super.key,
    required this.storeName,
    required this.surgeBonus,
    required this.activeBatches,
    required this.onTap,
  });

  @override
  State<StoreDemandMarker> createState() => _StoreDemandMarkerState();
}

class _StoreDemandMarkerState extends State<StoreDemandMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Radial Breathing Pulse (Demand Bloom)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final scale = 1.0 + (_pulseController.value * 0.45);
                final opacity = (1.0 - _pulseController.value).clamp(0.0, 1.0);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          gold.withValues(alpha: 0.35 * opacity),
                          gold.withValues(alpha: 0.05 * opacity),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),

            // 2. Central Tactical Store Pin
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.storefront_rounded, color: gold, size: 22),
            ),

            // 3. Floating Surge Pay Pill
            Positioned(
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 12, color: Colors.black),
                    const SizedBox(width: 2),
                    Text(
                      '+${widget.surgeBonus.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
