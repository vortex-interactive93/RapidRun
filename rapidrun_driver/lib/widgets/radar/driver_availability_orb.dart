// File: rapidrun_driver/lib/widgets/radar/driver_availability_orb.dart

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

enum DriverShiftStatus { offline, searching, dispatchLocked }

class DriverAvailabilityOrb extends StatefulWidget {
  final DriverShiftStatus initialStatus;
  final ValueChanged<DriverShiftStatus> onStatusChanged;

  const DriverAvailabilityOrb({
    super.key,
    this.initialStatus = DriverShiftStatus.offline,
    required this.onStatusChanged,
  });

  @override
  State<DriverAvailabilityOrb> createState() => _DriverAvailabilityOrbState();
}

class _DriverAvailabilityOrbState extends State<DriverAvailabilityOrb>
    with TickerProviderStateMixin {
  late DriverShiftStatus _currentStatus;
  late final AnimationController _pulseController;
  late final AnimationController _springController;
  double _dragDistortion = 0.0;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialStatus;

    // Continuous radial breathing pulse isolated to painter
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Unbounded spring controller for realistic gesture snapping
    _springController = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _springController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.heavyImpact();
    setState(() {
      _currentStatus = _currentStatus == DriverShiftStatus.offline
          ? DriverShiftStatus.searching
          : DriverShiftStatus.offline;
    });
    widget.onStatusChanged(_currentStatus);

    // Trigger explosive radial snap
    final spring = SpringSimulation(
      const SpringDescription(mass: 0.5, stiffness: 220.0, damping: 18.0),
      0.0,
      1.0,
      -8.0,
    );
    _springController.animateWith(spring);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _handleTap,
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragDistortion = (details.localPosition.dy / 100).clamp(-0.4, 0.4);
          });
        },
        onVerticalDragEnd: (_) {
          setState(() => _dragDistortion = 0.0);
        },
        child: SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _OrbCanvasPainter(
              pulseAnimation: _pulseController,
              springAnimation: _springController,
              status: _currentStatus,
              distortion: _dragDistortion,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbCanvasPainter extends CustomPainter {
  final Animation<double> pulseAnimation;
  final Animation<double> springAnimation;
  final DriverShiftStatus status;
  final double distortion;

  _OrbCanvasPainter({
    required this.pulseAnimation,
    required this.springAnimation,
    required this.status,
    required this.distortion,
  }) : super(repaint: Listenable.merge([pulseAnimation, springAnimation]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final isOnline = status == DriverShiftStatus.searching;

    final primaryColor = isOnline
        ? const Color(0xFF00E676) // High-visibility Emerald
        : const Color(0xFFE5A93C); // RapidRun Gold Accent

    // 1. Ambient Bloom Wave
    final pulseRadius = (size.width / 2.3) + (pulseAnimation.value * 8.0);
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: isOnline ? 0.22 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawCircle(center, pulseRadius, glowPaint);

    // 2. Physical Glass Core with Touch Distortion
    final coreRadius = (size.width / 3.0) + (springAnimation.value * 2.0);
    final coreRect = Rect.fromCenter(
      center: center,
      width: coreRadius * 2,
      height: (coreRadius * 2) * (1.0 + distortion),
    );

    final coreGradient = RadialGradient(
      colors: [
        primaryColor,
        primaryColor.withValues(alpha: 0.65),
        const Color(0xFF14171D),
      ],
      stops: const [0.2, 0.7, 1.0],
    );

    final corePaint = Paint()
      ..shader = coreGradient.createShader(coreRect)
      ..style = PaintingStyle.fill;

    canvas.drawOval(coreRect, corePaint);

    // 3. Hardware Specular Ring
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(coreRect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbCanvasPainter oldDelegate) => false;
}
