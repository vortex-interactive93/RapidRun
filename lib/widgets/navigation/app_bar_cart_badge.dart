// File: lib/widgets/navigation/app_bar_cart_badge.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

class AppBarCartBadge extends StatefulWidget {
  const AppBarCartBadge({super.key});

  @override
  State<AppBarCartBadge> createState() => _AppBarCartBadgeState();
}

class _AppBarCartBadgeState extends State<AppBarCartBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _badgeAnimController;
  late final Animation<double> _scaleAnimation;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _badgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_badgeAnimController);

    cartState.addListener(_onCartChanged);
    _lastCount = cartState.totalItemCount;
  }

  void _onCartChanged() {
    final count = cartState.totalItemCount;
    if (count != _lastCount) {
      if (count > _lastCount) {
        _badgeAnimController.forward(from: 0.0);
      }
      _lastCount = count;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    cartState.removeListener(_onCartChanged);
    _badgeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = cartState.totalItemCount;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, '/cart');
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF161922),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: count > 0
                    ? const Color(0xFFE5A93C).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  color: count > 0 ? const Color(0xFFE5A93C) : Colors.white70,
                  size: 20,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A93C),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Color(0xFF0F1115),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
