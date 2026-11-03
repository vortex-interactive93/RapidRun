/// Design tokens for the RapidRun Driver experience.
/// These form the visual language foundation and allow us to:
///  - Rapidly theme new components
///  - Maintain consistency while differentiating from commodity gig apps
///  - Enable future dynamic theming (time-of-day, probability states, etc.)
///
/// NOTE: Early draft – expect evolution once we finalize brand voice.
import 'package:flutter/material.dart';

@immutable
class DesignTokens {
  const DesignTokens._();

  // Primary accent (energetic amber) & secondary (cool indigo) create a dual-tone identity.
  static const primary = Color(0xFFFF9F2D); // Amber / Momentum
  static const primaryBright = Color(0xFFFFB755);
  static const primaryDim = Color(0xFFCE7C17);

  static const secondary = Color(0xFF566BFF); // Indigo / Stability
  static const secondaryBright = Color(0xFF6F82FF);
  static const secondaryDim = Color(0xFF3950D9);

  // Support semantic roles (availability states, routing, alerts, opportunities)
  static const available = Color(0xFF31D992);
  static const transitioning = Color(0xFFF3C93D);
  static const routing = Color(0xFF6AA8FF);
  static const alert = Color(0xFFFF4D5C);
  static const info = Color(0xFF4DB5FF);
  static const opportunity = Color(
    0xFF8F6BFF,
  ); // Used in future demand bloom layer

  // Performance (earnings pace) semantic shades
  static const pacePositive = Color(0xFF3AD07A); // trending above baseline
  static const paceNegative = Color(0xFFCC4758); // below baseline
  static const paceNeutral = Color(0xFF6D7780);

  // Demand bloom heat colors (for gradient cluster visualization)
  static const bloomCool = Color(0xFF27466B);
  static const bloomWarm = Color(0xFF8F6BFF); // ties to opportunity
  static const bloomHot = Color(0xFFFF7A3D);
  static const bloomCore = Color(0xFFFFC64D);

  // Surfaces
  static const surfaceBase = Color(0xFF0F1215);
  static const surfaceElevated = Color(0xFF181C21);
  static const surfaceFrost = Color(
    0x1AFFFFFF,
  ); // 10% white overlay (apply blur beneath)

  // Text / content colors
  static const textStrong = Color(0xFFE8ECEF);
  static const text = Color(0xFFCBD3D9);
  static const textMuted = Color(0xFF8A949C);
  static const textFaint = Color(0xFF5A636B);

  // Divider / stroke
  static const stroke = Color(0xFF283037);
  static const strokeSoft = Color(0xFF1D2328);

  // Spacing scale
  static const s0 = 0.0;
  static const s1 = 2.0;
  static const s2 = 4.0;
  static const s3 = 6.0;
  static const s4 = 8.0;
  static const s5 = 10.0;
  static const s6 = 12.0;
  static const s8 = 16.0;
  static const s10 = 20.0;
  static const s12 = 24.0;
  static const s14 = 28.0;
  static const s16 = 32.0;
  static const s20 = 40.0;

  // Radii
  static const radiusXs = 4.0;
  static const radiusSm = 8.0;
  static const radiusMd = 14.0;
  static const radiusLg = 22.0;
  static const radiusPill = 999.0;

  // Elevation (shadow tokens – kept subtle)
  static const shadow1 = [
    BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const shadowSoft = [
    BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
  ];

  // Typography presets (we keep these light; final mapping via ThemeData)
  static TextStyle get labelUpper => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.9,
    color: textMuted,
  );

  static TextStyle get numberStrong => const TextStyle(
    fontSize: 18,
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w600,
    color: textStrong,
  );

  static TextStyle get micro =>
      const TextStyle(fontSize: 10, letterSpacing: 0.4, color: textFaint);

  // Blur & translucency presets (for BackdropFilter usage guidelines)
  static const double blurXs = 4.0; // subtle
  static const double blurSm = 8.0; // standard panel
  static const double blurMd = 16.0; // heavy glass

  // Gradient surfaces
  static const gradientPanel = LinearGradient(
    colors: [Color(0x1FFFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientAccentSheen = LinearGradient(
    colors: [primaryBright, secondaryBright],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const radialMenuGradient = LinearGradient(
    colors: [primaryBright, secondaryBright],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const bloomClusterGradient = RadialGradient(
    colors: [bloomCore, bloomHot, bloomWarm, bloomCool],
    stops: [0.05, 0.25, 0.55, 1.0],
  );
}

/// Theme extension for dynamic references (allows future adaptive shifts like time-of-day).
class DriverDesign extends ThemeExtension<DriverDesign> {
  final Color availabilityGlow;
  final Color demandBloom;
  final Gradient orbIdleGradient;
  final Gradient orbActiveGradient;

  const DriverDesign({
    required this.availabilityGlow,
    required this.demandBloom,
    required this.orbIdleGradient,
    required this.orbActiveGradient,
  });

  factory DriverDesign.fallback() => const DriverDesign(
    availabilityGlow: DesignTokens.available,
    demandBloom: DesignTokens.opportunity,
    orbIdleGradient: LinearGradient(
      colors: [DesignTokens.surfaceElevated, DesignTokens.surfaceBase],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    orbActiveGradient: LinearGradient(
      colors: [DesignTokens.primary, DesignTokens.secondary],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  @override
  ThemeExtension<DriverDesign> copyWith({
    Color? availabilityGlow,
    Color? demandBloom,
    Gradient? orbIdleGradient,
    Gradient? orbActiveGradient,
  }) => DriverDesign(
    availabilityGlow: availabilityGlow ?? this.availabilityGlow,
    demandBloom: demandBloom ?? this.demandBloom,
    orbIdleGradient: orbIdleGradient ?? this.orbIdleGradient,
    orbActiveGradient: orbActiveGradient ?? this.orbActiveGradient,
  );

  @override
  ThemeExtension<DriverDesign> lerp(
    ThemeExtension<DriverDesign>? other,
    double t,
  ) {
    if (other is! DriverDesign) return this;
    return DriverDesign(
      availabilityGlow: Color.lerp(
        availabilityGlow,
        other.availabilityGlow,
        t,
      )!,
      demandBloom: Color.lerp(demandBloom, other.demandBloom, t)!,
      orbIdleGradient: LinearGradient(
        colors: List.generate(
          2,
          (i) => Color.lerp(
            (orbIdleGradient as LinearGradient).colors[i],
            (other.orbIdleGradient as LinearGradient).colors[i],
            t,
          )!,
        ),
      ),
      orbActiveGradient: LinearGradient(
        colors: List.generate(
          2,
          (i) => Color.lerp(
            (orbActiveGradient as LinearGradient).colors[i],
            (other.orbActiveGradient as LinearGradient).colors[i],
            t,
          )!,
        ),
      ),
    );
  }
}
