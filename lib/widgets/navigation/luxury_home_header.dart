// File: lib/widgets/navigation/luxury_home_header.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

class LuxuryHomeHeader extends StatelessWidget {
  final VoidCallback onAddressTap;
  final VoidCallback onCartTap;

  const LuxuryHomeHeader({
    super.key,
    required this.onAddressTap,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: customerState,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Address Selector Dropdown Pill
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAddressTap();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'DELIVER TO',
                          style: TextStyle(
                            color: Color(0xFFE5A93C),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.8),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerState.address,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              // Membership Tier Badge & Cart
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      customerState.tierName.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFE5A93C),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
                    onPressed: onCartTap,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
