// File: lib/screens/shell/bottom_nav_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../navigation/app_navigator.dart';
import '../home/home_page.dart';
import '../orders/order_history_screen.dart';
import '../shopping/cart_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/navigation/smart_floating_cart_hud.dart';

/// Root shell with persistent bottom navigation similar to retail apps.
/// Uses an IndexedStack to preserve state of each tab.
class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;

  late final List<_TabSpec> _tabs = [
    _TabSpec(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      builder: () => const HomePage(),
    ),
    _TabSpec(
      label: 'Orders',
      icon: Icons.history_toggle_off,
      activeIcon: Icons.history,
      builder: () => const OrderHistoryScreen(),
    ),
    _TabSpec(
      label: 'Cart',
      iconWidget: const _CartNavIcon(),
      activeIconWidget: const _CartNavIcon(active: true),
      builder: () => const CartScreen(),
    ),
    _TabSpec(
      label: 'Account',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      builder: () => const ProfileScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    navigationState.addListener(_onNavStateChanged);
  }

  @override
  void dispose() {
    navigationState.removeListener(_onNavStateChanged);
    super.dispose();
  }

  void _onNavStateChanged() {
    if (_index != navigationState.currentTabIndex && mounted) {
      setState(() => _index = navigationState.currentTabIndex);
    }
  }

  void _onDestinationSelected(int i) {
    if (_index == i && i == 0) {
      AppNavigator.popToRoot(context);
      return;
    }
    HapticFeedback.selectionClick();
    navigationState.switchTab(i);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _tabs.length) _index = 0;
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: _tabs
                .map(
                  (t) => KeyedSubtree(
                    key: PageStorageKey(t.label),
                    child: t.builder(),
                  ),
                )
                .toList(),
          ),
          SmartFloatingCartHud(
            currentTabIndex: _index,
            onViewCartPressed: () => _onDestinationSelected(2),
            onCheckoutPressed: () => _onDestinationSelected(2),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 60,
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        indicatorColor: Colors.transparent,
        destinations: _tabs
            .asMap()
            .entries
            .map(
              (entry) => entry.value.toDestination(
                context,
                _index,
                isActive: entry.key == _index,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData? icon;
  final IconData? activeIcon;
  final Widget Function() builder;
  final Widget? iconWidget;
  final Widget? activeIconWidget;
  _TabSpec({
    required this.label,
    required this.builder,
    this.icon,
    this.activeIcon,
    this.iconWidget,
    this.activeIconWidget,
  });

  NavigationDestination toDestination(
    BuildContext context,
    int currentIndex, {
    bool isActive = false,
  }) {
    final highlight = Theme.of(context).colorScheme.primary;
    final baseColor = Theme.of(context).iconTheme.color;
    final unselected = baseColor == null
        ? null
        : baseColor.withValues(alpha: baseColor.a * 0.85);
    Widget iconWidgetFinal =
        iconWidget ??
        Icon(icon, key: ValueKey(label), size: 38, color: unselected);
    Widget activeIconWidgetFinal =
        activeIconWidget ??
        Icon(
          activeIcon ?? icon,
          key: ValueKey('$label-active'),
          size: 35,
          color: highlight,
        );
    const yOffset = 10.0;
    Widget wrap(Widget child, bool active) {
      return AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: active ? 1.12 : 1.0,
        curve: Curves.easeOut,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (active)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highlight.withValues(alpha: 0.10),
                ),
              ),
            child,
          ],
        ),
      );
    }

    return NavigationDestination(
      icon: Transform.translate(
        offset: const Offset(0, yOffset),
        child: wrap(iconWidgetFinal, false),
      ),
      selectedIcon: Transform.translate(
        offset: const Offset(0, yOffset),
        child: wrap(activeIconWidgetFinal, true),
      ),
      label: label,
    );
  }
}

/// Cart icon with dynamic badge showing total items.
class _CartNavIcon extends StatelessWidget {
  final bool active;
  const _CartNavIcon({this.active = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartState,
      builder: (context, _) {
        final count = cartState.totalItemCount;
        final highlight = Theme.of(context).colorScheme.primary;
        final inactive = Theme.of(context).iconTheme.color;
        final color = active
            ? highlight
            : (inactive == null
                  ? null
                  : inactive.withValues(alpha: inactive.a * 0.85));
        final baseIcon = Icon(
          active ? Icons.shopping_cart : Icons.shopping_cart_outlined,
          size: 38,
          color: color,
        );
        if (count == 0) return baseIcon;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            baseIcon,
            Positioned(
              top: -6,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(minWidth: 19),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
