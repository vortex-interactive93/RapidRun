// File: rapidrun_driver/lib/presentation/home/widgets/pulsing_radar_puck.dart

import 'package:flutter/material.dart';

class PulsingRadarPuck extends StatefulWidget {
  final double heading;

  const PulsingRadarPuck({super.key, this.heading = 0.0});

  @override
  State<PulsingRadarPuck> createState() => _PulsingRadarPuckState();
}

class _PulsingRadarPuckState extends State<PulsingRadarPuck> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final scale = 1.0 + (_anim.value * 1.6);
        final opacity = (1.0 - _anim.value).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Sonar Echo Pulse
            Transform.scale(
              scale: scale,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withValues(alpha: 0.25 * opacity),
                  border: Border.all(color: gold.withValues(alpha: 0.5 * opacity), width: 1.5),
                ),
              ),
            ),

            // Core Metallic Radar Puck
            Transform.rotate(
              angle: widget.heading * (3.1415926535 / 180),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14171F),
                  border: Border.all(color: gold, width: 2.2),
                  boxShadow: [
                    BoxShadow(color: gold.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.navigation_rounded, color: gold, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
