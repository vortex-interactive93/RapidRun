// File: lib/widgets/navigation/floating_cart_hud.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/rolling_digit_counter.dart';

class FloatingCartHUD extends StatefulWidget {
  final int itemCount;
  final double subtotal;
  final VoidCallback onCheckout;

  const FloatingCartHUD({
    super.key,
    required this.itemCount,
    required this.subtotal,
    required this.onCheckout,
  });

  @override
  State<FloatingCartHUD> createState() => _FloatingCartHUDState();
}

class _FloatingCartHUDState extends State<FloatingCartHUD>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.04).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(covariant FloatingCartHUD oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount || oldWidget.subtotal != widget.subtotal) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();

    return Positioned(
      bottom: 22,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onCheckout();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: const Color(0xFF131620).withValues(alpha: 0.94),
              border: Border.all(
                color: const Color(0xFFE5A93C).withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 26,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      // 1. Gold Pill Quantity Badge with Bag Icon
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A93C),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_rounded,
                              color: Color(0xFF0F1115),
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${widget.itemCount}',
                              style: const TextStyle(
                                color: Color(0xFF0F1115),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 2. Clear "View Bag" Action Label
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'View Bag',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            widget.itemCount == 1 ? '1 item added' : '${widget.itemCount} items added',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // 3. Physical Tumbler Price Counter
                      RollingDigitCounter(
                        value: widget.subtotal,
                        prefix: r'$',
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        textStyle: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 4. Circular Forward Chevron Pill
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFFE5A93C),
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
