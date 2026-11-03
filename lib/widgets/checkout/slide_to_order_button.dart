// File: lib/widgets/checkout/slide_to_order_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideToOrderButton extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  final double totalAmount;

  const SlideToOrderButton({
    super.key,
    required this.onConfirmed,
    required this.totalAmount,
  });

  @override
  State<SlideToOrderButton> createState() => _SlideToOrderButtonState();
}

class _SlideToOrderButtonState extends State<SlideToOrderButton> {
  double _dragProgress = 0.0;
  bool _isSubmitted = false;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const double trackHeight = 62.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - trackHeight;

        return Container(
          height: trackHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2129),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(color: gold.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Dynamic Fill Track
              Container(
                width: trackHeight + (_dragProgress * maxDrag),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(31),
                  gradient: LinearGradient(
                    colors: [
                      gold.withValues(alpha: 0.15),
                      gold.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),

              // Animated Shimmer Callout Text
              Center(
                child: Opacity(
                  opacity: (1.0 - (_dragProgress * 1.5)).clamp(0.0, 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SLIDE TO DISPATCH • \$${widget.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, color: gold, size: 16),
                    ],
                  ),
                ),
              ),

              // Draggable Puck Thumb
              Positioned(
                left: _dragProgress * maxDrag,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isSubmitted) return;
                    setState(() {
                      _dragProgress = (_dragProgress + (details.primaryDelta! / maxDrag)).clamp(0.0, 1.0);
                    });
                    if (_dragProgress > 0.85) HapticFeedback.selectionClick();
                  },
                  onHorizontalDragEnd: (details) async {
                    if (_dragProgress >= 0.90 && !_isSubmitted) {
                      setState(() {
                        _dragProgress = 1.0;
                        _isSubmitted = true;
                      });
                      HapticFeedback.heavyImpact();
                      await widget.onConfirmed();
                    } else {
                      setState(() => _dragProgress = 0.0);
                    }
                  },
                  child: Container(
                    width: trackHeight,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFCD34D), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSubmitted
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                            )
                          : const Icon(Icons.bolt_rounded, color: Colors.black, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
