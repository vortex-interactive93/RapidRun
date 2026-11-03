// File: packages/rapidrun_shared/lib/state/navigation_state.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NavigationState extends ChangeNotifier {
  int _currentTabIndex = 0;
  final GlobalKey<NavigatorState> homeNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> ordersNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> cartNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> accountNavKey = GlobalKey<NavigatorState>();

  int get currentTabIndex => _currentTabIndex;

  void switchTab(int index) {
    if (_currentTabIndex == index) {
      // 1-TAP HOME ESCAPE: Popping to root if already on current tab
      _popCurrentTabToRoot();
      return;
    }
    HapticFeedback.selectionClick();
    _currentTabIndex = index;
    notifyListeners();
  }

  void resetToHome() {
    HapticFeedback.heavyImpact();
    _currentTabIndex = 0;
    _popCurrentTabToRoot();
    notifyListeners();
  }

  void _popCurrentTabToRoot() {
    NavigatorState? targetNav;
    switch (_currentTabIndex) {
      case 0:
        targetNav = homeNavKey.currentState;
        break;
      case 1:
        targetNav = ordersNavKey.currentState;
        break;
      case 2:
        targetNav = cartNavKey.currentState;
        break;
      case 3:
        targetNav = accountNavKey.currentState;
        break;
    }
    targetNav?.popUntil((route) => route.isFirst);
  }
}

final navigationState = NavigationState();
