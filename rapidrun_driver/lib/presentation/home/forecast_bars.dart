import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:rapidrun_driver/theme/design_tokens.dart';

/// Simple vertical bar series representing hourly forecast intensity.
class ForecastBars extends StatelessWidget {
  final List<double> values; // 0..1
  final int highlightIndex;
  const ForecastBars({
    super.key,
    required this.values,
    required this.highlightIndex,
  });

  @override
  Widget build(BuildContext context) {
    final maxH = 56.0;
    return SizedBox(
      height: maxH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++) ...[
            _Bar(
              height: (values[i].clamp(0.0, 1.0)) * maxH,
              highlight: i == highlightIndex,
            ),
            if (i != values.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final bool highlight;
  const _Bar({required this.height, required this.highlight});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      width: 10,
      height: height < 4 ? 4 : height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: highlight
              ? [DesignTokens.secondaryBright, DesignTokens.secondary]
              : [
                  DesignTokens.primaryBright.withOpacity(.85),
                  DesignTokens.primary.withOpacity(.85),
                ],
        ),
        boxShadow: highlight
            ? [
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Generate mock demand values with deterministic randomness.
List<double> mockForecastSeries(int count) {
  final r = math.Random(13);
  return List.generate(count, (i) {
    final base = 0.2 + r.nextDouble() * 0.8; // 0.2..1.0
    // Smoothness factor
    final smooth = (math.sin(i / 2) + 1) / 2; // 0..1
    return (base * 0.6 + smooth * 0.4).clamp(0.0, 1.0);
  });
}
