import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:rapidrun_driver/theme/design_tokens.dart';

/// Horizontal metrics strip displaying live driver performance indicators.
/// Phase 2: uses placeholder mock values; future: wire to analytics / Firestore aggregates.
class MetricsStrip extends StatelessWidget {
  final double acceptance; // 0-1
  final double earningsPace; // relative to baseline 1.0 = baseline
  final Duration active; // active time today
  final bool dense;
  const MetricsStrip({
    super.key,
    required this.acceptance,
    required this.earningsPace,
    required this.active,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = active.inMinutes;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    String activeLabel = h > 0 ? '${h}h ${m}m' : '${m}m';
    final chipPad = dense
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: DesignTokens.surfaceElevated.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MetricChip(
              label: 'Acceptance',
              value: '${(acceptance * 100).clamp(0, 100).toStringAsFixed(0)}%',
              pad: chipPad,
              accent: acceptance >= 0.75
                  ? DesignTokens.available
                  : DesignTokens.transitioning,
            ),
            const SizedBox(width: 8),
            _MetricChip(
              label: 'Pace',
              value: earningsPace >= 1
                  ? '+${((earningsPace - 1) * 100).toStringAsFixed(0)}%'
                  : '-${((1 - earningsPace) * 100).toStringAsFixed(0)}%',
              pad: chipPad,
              accent: earningsPace >= 1
                  ? DesignTokens.secondary
                  : DesignTokens.textFaint,
              trailing: SizedBox(
                width: 40,
                height: 16,
                child: CustomPaint(painter: _SparkPainter()),
              ),
            ),
            const SizedBox(width: 8),
            _MetricChip(
              label: 'Active',
              value: activeLabel,
              pad: chipPad,
              accent: DesignTokens.info,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final EdgeInsets pad;
  final Color accent;
  final Widget? trailing;
  const _MetricChip({
    required this.label,
    required this.value,
    required this.pad,
    required this.accent,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: DesignTokens.labelUpper.copyWith(
                  fontSize: 9,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.9), accent.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7); // deterministic placeholder
    final path = Path();
    final h = size.height;
    for (int i = 0; i < size.width.toInt(); i++) {
      final y = h - (r.nextDouble() * h);
      if (i == 0)
        path.moveTo(0, y);
      else
        path.lineTo(i.toDouble(), y);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = DesignTokens.secondaryBright.withOpacity(0.9);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
