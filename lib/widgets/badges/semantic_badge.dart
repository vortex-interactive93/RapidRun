import 'package:flutter/material.dart';

class SemanticBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final EdgeInsets padding;
  final double radius;
  final Color? foreground;
  const SemanticBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.radius = 8,
    this.foreground,
  });
  @override
  Widget build(BuildContext context) {
    final fg =
        foreground ??
        (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}
