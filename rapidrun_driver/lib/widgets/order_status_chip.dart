import 'package:flutter/material.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../theme/driver_theme_extension.dart';

/// Compact pill chip for order status with subtle gradient + dot.
class OrderStatusChip extends StatelessWidget {
  final OrderStatus status;
  final bool elevated;
  final bool compact; // smaller horizontal padding
  const OrderStatusChip({
    super.key,
    required this.status,
    this.elevated = false,
    this.compact = false,
  });

  Color _colorFor(DriverTheme dt) {
    switch (status) {
      case OrderStatus.pending:
        return dt.pending;
      case OrderStatus.assigned:
        return dt.assigned;
      case OrderStatus.shopping:
        return dt.shopping;
      case OrderStatus.ready_for_delivery:
        return dt.readyForDelivery;
      case OrderStatus.enroute:
        return dt.enroute;
      case OrderStatus.delivered:
        return dt.delivered;
      case OrderStatus.canceled:
        return dt.canceled;
      default:
        return dt.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt =
        Theme.of(context).extension<DriverTheme>() ?? DriverTheme.fallback;
    final baseColor = _colorFor(dt);
    final label = orderStatusLabel(status).toUpperCase();
    final gradient = LinearGradient(
      colors: [baseColor.withOpacity(.95), baseColor.withOpacity(.60)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final textColor = Colors.white;
    final padH = compact ? 8.0 : 10.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: baseColor.withOpacity(.40),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
        border: Border.all(color: baseColor.withOpacity(.9), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: textColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
