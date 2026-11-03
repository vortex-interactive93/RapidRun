// File: rapidrun_driver/lib/widgets/map/driver_map_overlay_painter.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class DriverMapOverlayPainter extends CustomPainter {
  final Animation<double> pulseAnimation;
  final bool isOnline;
  final double driverHeadingDegrees;

  DriverMapOverlayPainter({
    required this.pulseAnimation,
    required this.isOnline,
    this.driverHeadingDegrees = 42.0,
  }) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    if (isOnline) {
      _paintSurgeHeatBloom(
        canvas,
        center: Offset(size.width * 0.76, size.height * 0.46),
        radius: 90.0,
        surgeLabel: '+\$2.50',
      );
    }

    _paintDriverPuck(
      canvas,
      position: Offset(size.width * 0.38, size.height * 0.52),
    );
  }

  void _paintSurgeHeatBloom(Canvas canvas, {required Offset center, required double radius, required String surgeLabel}) {
    // 1. Multi-tier Gaussian Surge Radiance
    final surgeGradient = RadialGradient(
      colors: [
        const Color(0xFFE5A93C).withValues(alpha: 0.28),
        const Color(0xFFE5A93C).withValues(alpha: 0.12),
        const Color(0xFFE5A93C).withValues(alpha: 0.0),
      ],
      stops: const [0.2, 0.65, 1.0],
    );

    final bloomPaint = Paint()
      ..shader = surgeGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, bloomPaint);

    // 2. High-Visibility Surge Multiplier Chip
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 62.0, height: 26.0),
      const Radius.circular(13.0),
    );

    final chipBackground = Paint()
      ..color = const Color(0xFF14171D).withValues(alpha: 0.94)
      ..style = PaintingStyle.fill;
    final chipBorder = Paint()
      ..color = const Color(0xFFE5A93C).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(chipRect, chipBackground);
    canvas.drawRRect(chipRect, chipBorder);

    final textSpan = TextSpan(
      text: surgeLabel,
      style: const TextStyle(
        color: Color(0xFFE5A93C),
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _paintDriverPuck(Canvas canvas, {required Offset position}) {
    // Continuous GPS ping wave
    final waveRadius = 14.0 + (pulseAnimation.value * 22.0);
    final wavePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: (1.0 - pulseAnimation.value) * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(position, waveRadius, wavePaint);

    // Solid hardware core
    final corePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(position, 8.0, corePaint);
    canvas.drawCircle(position, 8.0, borderPaint);

    // Orientation Heading Cone
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(driverHeadingDegrees * (math.pi / 180.0));

    final headingPath = Path()
      ..moveTo(0, -16)
      ..lineTo(-5, -9)
      ..lineTo(5, -9)
      ..close();

    final headingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(headingPath, headingPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DriverMapOverlayPainter oldDelegate) =>
      oldDelegate.isOnline != isOnline || oldDelegate.driverHeadingDegrees != driverHeadingDegrees;
}
