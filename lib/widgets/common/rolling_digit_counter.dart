// File: lib/widgets/common/rolling_digit_counter.dart

import 'package:flutter/material.dart';

class RollingDigitCounter extends StatelessWidget {
  final double value;
  final String prefix;
  final Duration duration;
  final Curve curve;
  final TextStyle textStyle;

  const RollingDigitCounter({
    super.key,
    required this.value,
    this.prefix = r'$',
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutBack,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(2)}',
          style: textStyle,
        );
      },
    );
  }
}
