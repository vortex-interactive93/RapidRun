// File: lib/widgets/navigation/smart_floating_cart_hud.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

class SmartFloatingCartHud extends StatelessWidget {
  final int currentTabIndex;
  final VoidCallback onCheckoutPressed;
  final VoidCallback onViewCartPressed;

  const SmartFloatingCartHud({
    super.key,
    required this.currentTabIndex,
    required this.onCheckoutPressed,
    required this.onViewCartPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartState,
      builder: (context, _) {
        final bool shouldShow = currentTabIndex != 2 && !cartState.isEmpty;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: shouldShow ? 76.0 : -100.0,
          left: 16.0,
          right: 16.0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: shouldShow ? 1.0 : 0.0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF181B22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5A93C),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                '${cartState.totalItemCount}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: onViewCartPressed,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ESTIMATED SUBTOTAL',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  '\$${cartState.subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            onViewCartPressed();
                          },
                          child: const Text(
                            'View Cart',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5A93C),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            onCheckoutPressed();
                          },
                          child: const Row(
                            children: [
                              Text(
                                'Checkout',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.black),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
