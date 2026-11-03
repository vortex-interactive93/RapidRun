import 'package:flutter/material.dart';

/// Theme extension to expose driver semantic colors.
class DriverTheme extends ThemeExtension<DriverTheme> {
  final Color pending;
  final Color assigned;
  final Color shopping;
  final Color readyForDelivery;
  final Color enroute;
  final Color delivered;
  final Color canceled;

  const DriverTheme({
    required this.pending,
    required this.assigned,
    required this.shopping,
    required this.readyForDelivery,
    required this.enroute,
    required this.delivered,
    required this.canceled,
  });

  @override
  DriverTheme copyWith({
    Color? pending,
    Color? assigned,
    Color? shopping,
    Color? readyForDelivery,
    Color? enroute,
    Color? delivered,
    Color? canceled,
  }) => DriverTheme(
    pending: pending ?? this.pending,
    assigned: assigned ?? this.assigned,
    shopping: shopping ?? this.shopping,
    readyForDelivery: readyForDelivery ?? this.readyForDelivery,
    enroute: enroute ?? this.enroute,
    delivered: delivered ?? this.delivered,
    canceled: canceled ?? this.canceled,
  );

  @override
  DriverTheme lerp(ThemeExtension<DriverTheme>? other, double t) {
    if (other is! DriverTheme) return this;
    return DriverTheme(
      pending: Color.lerp(pending, other.pending, t)!,
      assigned: Color.lerp(assigned, other.assigned, t)!,
      shopping: Color.lerp(shopping, other.shopping, t)!,
      readyForDelivery: Color.lerp(
        readyForDelivery,
        other.readyForDelivery,
        t,
      )!,
      enroute: Color.lerp(enroute, other.enroute, t)!,
      delivered: Color.lerp(delivered, other.delivered, t)!,
      canceled: Color.lerp(canceled, other.canceled, t)!,
    );
  }

  static const fallback = DriverTheme(
    pending: Color(0xFF8E8E8E),
    assigned: Color(0xFF4DA3FF),
    shopping: Color(0xFFFFC947),
    readyForDelivery: Color(0xFF7ED957),
    enroute: Color(0xFF6A5BFF),
    delivered: Color(0xFF3DDC84),
    canceled: Color(0xFFFF5F56),
  );
}
