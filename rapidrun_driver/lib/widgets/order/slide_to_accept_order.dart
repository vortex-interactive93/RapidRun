// File: rapidrun_driver/lib/widgets/order/slide_to_accept_order.dart

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class SlideToAcceptOrder extends StatefulWidget {
  final Future<void> Function() onAccepted;
  final String label;

  const SlideToAcceptOrder({
    super.key,
    required this.onAccepted,
    this.label = 'SLIDE TO ACCEPT BATCH',
  });

  @override
  State<SlideToAcceptOrder> createState() => _SlideToAcceptOrderState();
}

class _SlideToAcceptOrderState extends State<SlideToAcceptOrder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  double _dragPosition = 0.0;
  bool _isLocked = false;

  static const double _knobSize = 52.0;
  static const double _trackHeight = 60.0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isLocked) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details, double maxDrag) async {
    if (_isLocked) return;

    if (_dragPosition >= maxDrag * 0.85) {
      HapticFeedback.heavyImpact();
      setState(() {
        _dragPosition = maxDrag;
        _isLocked = true;
      });
      await widget.onAccepted();
    } else {
      final simulation = SpringSimulation(
        const SpringDescription(mass: 0.5, stiffness: 280.0, damping: 22.0),
        _dragPosition,
        0.0,
        details.primaryVelocity ?? 0.0,
      );
      _springController.animateWith(simulation);
      _springController.addListener(() {
        if (!_isLocked && mounted) {
          setState(() {
            _dragPosition = _springController.value.clamp(0.0, maxDrag);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = trackWidth - _knobSize - 8.0;

        // Progressive fade as the knob slides across the text
        final textOpacity = (1.0 - (_dragPosition / (maxDrag * 0.65))).clamp(0.0, 1.0);

        return Container(
          height: _trackHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF14171D),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: Border.all(
              color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1. Dynamic Golden Gradient Track Fill
              Container(
                width: _dragPosition + _knobSize + 4.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE5A93C).withValues(alpha: 0.15),
                      const Color(0xFFE5A93C).withValues(alpha: 0.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                ),
              ),

              // 2. Unobstructed Label (Offset so knob never blocks text at rest)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(left: _knobSize + 10.0, right: 16.0),
                  child: Align(
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: _isLocked ? 1.0 : textOpacity,
                      child: Text(
                        _isLocked ? 'LOCKING DISPATCH...' : widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Tactile Gold Draggable Knob
              Positioned(
                left: _dragPosition + 4.0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, maxDrag),
                  onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, maxDrag),
                  child: Container(
                    width: _knobSize,
                    height: _knobSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFD54F), Color(0xFFE5A93C)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _isLocked
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.black,
                            size: 26,
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
