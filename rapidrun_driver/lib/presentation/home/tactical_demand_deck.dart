// File: rapidrun_driver/lib/presentation/home/tactical_demand_deck.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class TacticalDemandDeck extends StatefulWidget {
  final List<double> hourlyDemandPointers;

  const TacticalDemandDeck({
    super.key,
    this.hourlyDemandPointers = const [
      0.15, 0.25, 0.35, 0.60, 0.85, 0.70, 0.45, 0.50, 0.65, 0.80, 0.95, 0.60, 0.40
    ],
  });

  @override
  State<TacticalDemandDeck> createState() => _TacticalDemandDeckState();
}

class _TacticalDemandDeckState extends State<TacticalDemandDeck> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF13151A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: gold.withValues(alpha: 0.25), width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: 28,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag indicator
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header with Animated Pulsing Surge Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bolt_rounded, color: gold, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'DEMAND & SURGE RADAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final glow = _pulseController.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F2618),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Color.lerp(const Color(0xFF22C55E), const Color(0xFF86EFAC), glow)!,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4ADE80).withValues(alpha: 0.2 * glow),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Text(
                              r'+$2.50 SURGE ACTIVE',
                              style: TextStyle(
                                color: Color(0xFF86EFAC),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Equalizer Bar Histogram
                  SizedBox(
                    height: 52,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: widget.hourlyDemandPointers.map((intensity) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final barHeight = (constraints.maxHeight * intensity).clamp(8.0, 52.0);
                                final isPeak = intensity >= 0.8;

                                return Container(
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: isPeak
                                          ? [const Color(0xFFE6B450), const Color(0xFFFDE047)]
                                          : [const Color(0xFF4B391A), const Color(0xFFB48528)],
                                    ),
                                    boxShadow: isPeak
                                        ? [
                                            BoxShadow(
                                              color: gold.withValues(alpha: 0.5),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hotspot Pill Strip
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _hotspotChip('Bath & Body Works', 'High Velocity', true),
                        const SizedBox(width: 8),
                        _hotspotChip('Westover Village', 'Peak Orders', true),
                        const SizedBox(width: 8),
                        _hotspotChip('Target', 'Steady', false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hotspotChip(String store, String status, bool isHigh) {
    const gold = Color(0xFFE6B450);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHigh ? gold.withValues(alpha: 0.35) : Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHigh ? Icons.local_fire_department_rounded : Icons.store_mall_directory_rounded,
            color: isHigh ? gold : Colors.white54,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            '$store • $status',
            style: TextStyle(
              color: isHigh ? Colors.white : Colors.white60,
              fontSize: 10.5,
              fontWeight: isHigh ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
