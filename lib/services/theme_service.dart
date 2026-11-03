// File: lib/services/theme_service.dart

import 'package:flutter/material.dart';

/// Centralized theme configuration.
/// Consolidates repeated gold & dark styling used across store/cart screens.
class ThemeService {
  static const _gold = Color(0xFFE6B450);
  static const _darkBg = Color(0xFF1F1F1F);
  static const _card = Color(0xFF181818);

  static ThemeData applyBase(ThemeData base) {
    return base;
  }

  static ThemeData getThemeData() {
    final base = ThemeData(brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary: _gold,
        secondary: _gold,
        surface: _card,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _card,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: _gold),
        titleTextStyle: TextStyle(
          color: _gold,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      cardTheme: const CardThemeData(
        color: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _gold),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static ThemeData withHighContrast(ThemeData base) {
    final scheme = base.colorScheme;
    final outlineColor = scheme.onSurface.withValues(alpha: 0.9);
    return base.copyWith(
      focusColor: scheme.primary.withValues(alpha: 0.30),
      hoverColor: scheme.primary.withValues(alpha: 0.08),
      splashColor: scheme.primary.withValues(alpha: 0.10),
      highlightColor: scheme.primary.withValues(alpha: 0.15),
      dividerColor: outlineColor.withValues(alpha: 0.6),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: outlineColor, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: outlineColor.withValues(alpha: 0.75),
            width: 2,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 3),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: outlineColor, width: 2),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.25);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            return null;
          }),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ).copyWith(
          side: WidgetStateProperty.all(
            BorderSide(color: outlineColor, width: 2),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return scheme.onPrimary.withValues(alpha: 0.20);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.onPrimary.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ).copyWith(
          side: WidgetStateProperty.all(
            BorderSide(color: outlineColor.withValues(alpha: 0.6), width: 1.8),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.18);
            }
            return null;
          }),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: outlineColor.withValues(alpha: 0.55), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        margin: const EdgeInsets.all(8),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: outlineColor.withValues(alpha: 0.45), width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        selectedTileColor: scheme.primary.withValues(alpha: 0.15),
        tileColor: scheme.surface,
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  static ThemeData withReducedMotion(ThemeData base) {
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.iOS: _NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.macOS: _NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.windows: _NoAnimationsPageTransitionsBuilder(),
          TargetPlatform.linux: _NoAnimationsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _NoAnimationsPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationsPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
