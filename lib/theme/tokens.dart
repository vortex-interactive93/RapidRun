import 'package:flutter/material.dart';

/// Central design tokens (spacing, radii, durations, elevations, opacities, breakpoints).
/// Non-breaking introduction: existing code can gradually migrate.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadii {
  static const Radius sm = Radius.circular(6);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(20);
  static const BorderRadius brSm = BorderRadius.all(sm);
  static const BorderRadius brMd = BorderRadius.all(md);
  static const BorderRadius brLg = BorderRadius.all(lg);
}

class AppDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration med = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 400);
}

class AppEasing {
  static const Curve standard = Curves.easeInOut;
  static const Curve emphasized = Curves.easeOutCubic;
}

class AppElevation {
  static const double level1 = 2;
  static const double level2 = 4;
  static const double level3 = 8;
}

class AppOpacities {
  static const double disabled = 0.38;
  static const double medium = 0.6;
  static const double subtle = 0.12;
}

class AppBreakpoints {
  static const double phone = 0; // base
  static const double tablet = 600;
  static const double desktop = 1024;
}

class AppShadows {
  static List<BoxShadow> soft([double opacity = 0.18]) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: opacity),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Helper for standard snackbar styling usage.
SnackBar appSnackBar(String message, {Color? background, IconData? icon}) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: background ?? Colors.black.withValues(alpha: 0.9),
    content: Row(
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        Expanded(child: Text(message)),
      ],
    ),
    shape: RoundedRectangleBorder(borderRadius: AppRadii.brMd),
    duration: const Duration(seconds: 3),
  );
}
