import 'package:flutter/material.dart';

/// Central place for color tokens & elevations.
/// Expand here as the visual language evolves.
class AppColors {
  AppColors._();

  // Core brand
  static const gold = Color(0xFFE6B450);
  static const goldBright = Color(0xFFF0C065);
  static const goldDark = Color(0xFFC8922A);

  // Neutrals (dark)
  static const background = Color(0xFF1F1F1F);
  static const surfaceLow = Color(0xFF181818); // app bar / drawer
  static const surface = Color(0xFF242424); // cards
  static const surfaceHigh = Color(0xFF2A2A2A); // raised

  // Support accents (used sparingly)
  static const accentViolet = Color(0xFF6E5AD9); // optional highlight
  static const accentTeal = Color(0xFF2FA7A0); // alternative

  // Semantic
  static const success = Color(0xFF2FAF6E);
  static const warning = Color(0xFFE1A833);
  static const error = Color(0xFFD95454);
  static const info = Color(0xFF4DA3E6);

  // Text shades
  static const textHigh = Color(0xFFF2F2F2);
  static const textMed = Color(0xFFC4C4C4);
  static const textLow = Color(0xFF9A9A9A);
}

/// Simple elevation shadow presets tuned for dark surfaces.
class AppShadows {
  AppShadows._();
  static List<BoxShadow> level1 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> level2 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}

enum HomeVisualStyle { classicGold, glassyShowcase, splitHighlight }
