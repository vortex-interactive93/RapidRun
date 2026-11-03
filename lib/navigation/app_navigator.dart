// File: lib/navigation/app_navigator.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/store/unified_store_catalog_screen.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Pops all routes back to the root tab view with haptics
  static void popToRoot(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  /// Replaces the entire stack with a specific store, skipping intermediary hub screens
  static void navigateDirectToStore({
    required BuildContext context,
    required Widget storeScreen,
  }) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => storeScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.fastOutSlowIn;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  /// Direct 1-tap entry into unified store catalog
  static void openStoreCatalog(
    BuildContext context, {
    required String storeName,
  }) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnifiedStoreCatalogScreen(storeName: storeName),
      ),
    );
  }
}
