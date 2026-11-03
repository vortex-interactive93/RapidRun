// File: rapidrun_driver/lib/widgets/radar/surge_radar_bar.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SurgeRadarVisualizer extends StatefulWidget {
  final double surgeMultiplier;
  final String activeZone;

  const SurgeRadarVisualizer({
    super.key,
    required this.surgeMultiplier,
    required this.activeZone,
  });

  @override
  State<SurgeRadarVisualizer> createState() => _SurgeRadarVisualizerState();
}

class _SurgeRadarVisualizerState extends State<SurgeRadarVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0xFFFFC107).withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.bolt, color: Color(0xFFFFC107), size: 18.0),
                  SizedBox(width: 6.0),
                  Text(
                    'DEMAND & SURGE RADAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  '+\$${widget.surgeMultiplier.toStringAsFixed(2)} SURGE ACTIVE',
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // RepaintBoundary isolates high-frequency canvas painting from the map
          RepaintBoundary(
            child: SizedBox(
              height: 48.0,
              width: double.infinity,
              child: CustomPaint(
                painter: _RadarWavePainter(
                  animation: _waveController,
                  barColor: const Color(0xFFFFC107),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarWavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color barColor;

  _RadarWavePainter({required this.animation, required this.barColor})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 28;
    final double barSpacing = size.width / barCount;
    final double barWidth = barSpacing * 0.65;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      // Harmonic wave calculation for natural audio-spectrum movement
      final double normalizedIndex = i / barCount;
      final double wavePhase = animation.value * 2 * math.pi;
      final double rawHeight = math.sin(normalizedIndex * 4 * math.pi + wavePhase);
      final double secondaryWave = math.cos(normalizedIndex * 2 * math.pi - wavePhase * 0.5);

      final double heightFactor = ((rawHeight + secondaryWave + 2.0) / 4.0).clamp(0.15, 1.0);
      final double currentBarHeight = size.height * heightFactor;

      final double x = i * barSpacing + (barSpacing - barWidth) / 2;
      final double y = size.height - currentBarHeight;

      // Draw rounded surge bars
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, currentBarHeight),
        const Radius.circular(3.0),
      );

      // Give higher peaks a brighter glow
      paint.color = barColor.withValues(alpha: 0.3 + (heightFactor * 0.7));
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) => false;
}
