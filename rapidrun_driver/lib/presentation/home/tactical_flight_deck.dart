// File: rapidrun_driver/lib/presentation/home/tactical_flight_deck.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TacticalFlightDeck extends StatelessWidget {
  final bool isOnline;
  final Duration? remainingTime;
  final double todayEarnings;
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenDrawer;
  final VoidCallback onRecenterMap;
  final VoidCallback? onOpenWallet;

  const TacticalFlightDeck({
    super.key,
    required this.isOnline,
    required this.remainingTime,
    required this.todayEarnings,
    required this.onToggleOnline,
    required this.onOpenDrawer,
    required this.onRecenterMap,
    this.onOpenWallet,
  });

  String _formatRemaining() {
    if (remainingTime == null) return 'No Cap';
    final hours = remainingTime!.inHours;
    final minutes = remainingTime!.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 14,
      right: 14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF14171D).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isOnline ? gold.withValues(alpha: 0.4) : Colors.white12,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Menu Trigger with Active Duty Pip
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onOpenDrawer();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                          if (isOnline)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Central Tactical Availability Capsule
                GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    onToggleOnline();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.fastOutSlowIn,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? gold.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOnline ? gold : Colors.white24,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? const Color(0xFF4ADE80) : Colors.redAccent,
                            boxShadow: [
                              if (isOnline)
                                BoxShadow(
                                  color: const Color(0xFF4ADE80).withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          isOnline ? 'ONLINE • ${_formatRemaining()}' : 'OFFLINE • TAP TO GO',
                          style: TextStyle(
                            color: isOnline ? gold : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Compact Earnings Capsule + Map Recenter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onOpenWallet?.call();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          '\$${todayEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: Colors.white70, size: 19),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onRecenterMap();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
