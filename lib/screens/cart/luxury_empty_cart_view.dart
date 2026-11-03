// File: lib/screens/cart/luxury_empty_cart_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LuxuryEmptyCartView extends StatelessWidget {
  final VoidCallback onExploreTapped;

  const LuxuryEmptyCartView({super.key, required this.onExploreTapped});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ambient Glowing Bag Icon
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF181B22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Color(0xFFE5A93C),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Your Bag is Empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your personal concierge is on standby. Select items from Bath & Body Works or ALDI to begin.',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Action Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A93C),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                onExploreTapped();
              },
              child: const Text(
                'EXPLORE CATALOGS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
