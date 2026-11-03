import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rapidrun_driver/theme/design_tokens.dart';

/// Availability Orb (Phase 1 scaffold)
/// ----------------------------------
/// Replaces the generic offline/online pill with a branded animated focal element.
/// Later phases: radial menu expansion, probability pulse, extend availability.
class AvailabilityOrb extends StatefulWidget {
  final bool online;
  final Duration? remaining; // null when offline
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  const AvailabilityOrb({
    super.key,
    required this.online,
    this.remaining,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  @override
  State<AvailabilityOrb> createState() => _AvailabilityOrbState();
}

class _AvailabilityOrbState extends State<AvailabilityOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design =
        Theme.of(context).extension<DriverDesign>() ?? DriverDesign.fallback();
    final active = widget.online;
    assert(() {
      _rebuilds++;
      if (_rebuilds % 75 == 0) {
        // ignore: avoid_print
        print('[Perf][AvailabilityOrb] rebuilds: $_rebuilds');
      }
      return true;
    }());
    return Semantics(
      label: 'Availability status',
      value: active
          ? (widget.remaining == null
                ? 'Online with no time cap'
                : 'Online, ${widget.remaining!.inMinutes} minutes remaining')
          : 'Offline',
      hint: active
          ? 'Tap to go offline, long press for availability menu'
          : 'Tap to go online',
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value; // 0..1 cycle
            final pulse = active
                ? (1 + math.sin(t * math.pi * 2) * 0.035)
                : 1.0;
            final glowOpacity = active
                ? (0.28 + math.sin(t * math.pi * 2) * 0.18)
                : 0.0;
            final remainingFrac = (widget.remaining == null)
                ? 0.0
                : (1 - (widget.remaining!.inSeconds / (4 * 3600))).clamp(
                    0.0,
                    1.0,
                  );

            return AnimatedScale(
              scale: pulse,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              child: SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ambient glow
                    Opacity(
                      opacity: glowOpacity,
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              (active
                                      ? DesignTokens.available
                                      : Colors.transparent)
                                  .withOpacity(0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Progress + rotating spectral highlight
                    CustomPaint(
                      size: const Size.square(108),
                      painter: _ArcPainter(
                        progress: active ? remainingFrac : 0,
                        color: active
                            ? DesignTokens.available
                            : DesignTokens.textFaint,
                        phase: t,
                      ),
                    ),
                    // Core orb body
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: active
                            ? design.orbActiveGradient
                            : design.orbIdleGradient,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(active ? 0.25 : 0.08),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: _InnerLabel(
                        online: active,
                        remaining: widget.remaining,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Debug-only global rebuild counter (not const to avoid tree-shake removal in profile/release).
int _rebuilds = 0;

class _InnerLabel extends StatelessWidget {
  final bool online;
  final Duration? remaining;
  const _InnerLabel({required this.online, this.remaining});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    String headline;
    String sub;
    if (!online) {
      headline = 'Offline';
      sub = 'Tap to Go';
    } else {
      if (remaining == null) {
        headline = 'Active';
        sub = 'No cap';
      } else {
        final mins = remaining!.inMinutes;
        if (mins >= 60) {
          final h = mins ~/ 60;
          final m = mins % 60;
          headline = '$h h';
          sub = m > 0 ? '+ $m m left' : 'remaining';
        } else {
          headline = '$mins m';
          sub = 'remaining';
        }
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          style: style.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: style.labelSmall?.copyWith(
            color: Colors.white70,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress; // 0..1
  final double phase;
  final Color color;
  _ArcPainter({
    required this.progress,
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 7;
    final phaseR = phase * math.pi * 2;

    // Background ring
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white12;
    canvas.drawCircle(center, radius, bg);

    if (progress > 0) {
      final sweep = (math.pi * 2) * progress;
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.6
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [color.withOpacity(0.15), color, color.withOpacity(0.35)],
          stops: const [0.0, 0.6, 1.0],
          transform: GradientRotation(phaseR * 0.15),
        ).createShader(rect.inflate(16));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        arcPaint,
      );

      // Rotating spectral highlight segment (decorative)
      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.6
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: phaseR,
          endAngle: phaseR + math.pi / 2,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.55),
          ],
        ).createShader(rect);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        phaseR,
        math.pi / 2,
        false,
        segPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.phase != phase || old.color != color;
}
