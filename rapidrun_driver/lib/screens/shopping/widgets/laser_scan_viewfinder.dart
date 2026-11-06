// File: rapidrun_driver/lib/screens/shopping/widgets/laser_scan_viewfinder.dart

import 'package:flutter/material.dart';

class LaserScanViewfinder extends StatefulWidget {
  final bool isProcessing;
  final bool isVerified;

  const LaserScanViewfinder({
    super.key,
    required this.isProcessing,
    required this.isVerified,
  });

  @override
  State<LaserScanViewfinder> createState() => _LaserScanViewfinderState();
}

class _LaserScanViewfinderState extends State<LaserScanViewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isVerified
        ? const Color(0xFF00C853) // Emerald Success
        : const Color(0xFFE5A93C); // RapidRun Gold

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        return Stack(
          children: [
            // 1. Viewfinder Corner Brackets
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 2.5),
              ),
            ),

            // 2. Animated Laser Sweep Line (Active during audit processing)
            if (widget.isProcessing && !widget.isVerified)
              AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: height * _scanAnimation.value,
                    left: 12,
                    right: 12,
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFFE5A93C),
                            Color(0xFFFFD54F),
                            Color(0xFFE5A93C),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE5A93C).withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // 3. Verification State Overlay
            if (widget.isVerified)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (context, val, child) => Transform.scale(
                    scale: val,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF0A0C10),
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
