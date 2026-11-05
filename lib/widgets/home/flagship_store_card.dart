// File: lib/widgets/home/flagship_store_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FlagshipType { bathAndBodyWorks, aldi }

class FlagshipStoreCard extends StatefulWidget {
  final FlagshipType type;
  final VoidCallback onTap;

  const FlagshipStoreCard({
    super.key,
    required this.type,
    required this.onTap,
  });

  @override
  State<FlagshipStoreCard> createState() => _FlagshipStoreCardState();
}

class _FlagshipStoreCardState extends State<FlagshipStoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBBW = widget.type == FlagshipType.bathAndBodyWorks;

    final primaryGradient = isBBW
        ? const [Color(0xFF2E1A22), Color(0xFF190D13)]
        : const [Color(0xFF0A192F), Color(0xFF040B15)];

    final glowColor = isBBW
        ? const Color(0xFFE5A93C).withValues(alpha: 0.35)
        : const Color(0xFF0072CE).withValues(alpha: 0.35);

    final accentBadge = isBBW ? const Color(0xFFE5A93C) : const Color(0xFFFFD100);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _controller.forward();
        },
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: Container(
          height: 195,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // 1. Ambient Background Glow Orbs
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBBW
                          ? const Color(0xFFD48166).withValues(alpha: 0.25)
                          : const Color(0xFFE35205).withValues(alpha: 0.25),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 2. Translucent Watermark Graphic Accent
                Positioned(
                  right: 18,
                  bottom: -10,
                  child: Icon(
                    isBBW ? Icons.spa_rounded : Icons.shopping_cart_rounded,
                    size: 130,
                    color: Colors.white.withValues(alpha: 0.035),
                  ),
                ),

                // 3. Foreground Details
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Category Pill & Delivery Estimate
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: accentBadge.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isBBW ? Icons.spa_rounded : Icons.shopping_basket_rounded,
                                  color: accentBadge,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isBBW ? 'FRAGRANCE & BODY' : 'GROCERY & VALUE',
                                  style: TextStyle(
                                    color: accentBadge,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '25–35 MIN',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Bottom Content: Store Identity & Action Arrow
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBBW ? 'Bath & Body Works' : 'ALDI Market',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isBBW
                                      ? 'Fine Fragrance, 3-Wick Candles & Hand Soaps'
                                      : 'Produce, Fresh Meat, Organic & ALDI Finds',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
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
