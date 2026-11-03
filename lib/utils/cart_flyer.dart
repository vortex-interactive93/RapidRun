import 'dart:ui';
import 'package:flutter/material.dart';

/// Coordinates fly-to-cart animations from product add sources to the cart badge.
class CartFlyer {
  static final CartFlyer instance = CartFlyer._();
  CartFlyer._();

  GlobalKey? _cartKey;
  final List<_ActiveFlight> _flights = [];

  void registerCartAnchor(GlobalKey key) => _cartKey = key;

  /// Launch a flight from the given origin widget context (typically the add button).
  void flyFrom(
    BuildContext context, {
    double size = 32,
    Color color = const Color(0xFFE6B450),
    VoidCallback? onComplete,
  }) {
    if (_cartKey == null) return;
    final overlay = Overlay.of(context); // non-null in normal material app tree
    final cartContext = _cartKey!.currentContext;
    if (cartContext == null) return;
    final renderBoxStart = context.findRenderObject() as RenderBox?;
    final renderBoxEnd = cartContext.findRenderObject() as RenderBox?;
    if (renderBoxStart == null || renderBoxEnd == null) return;
    final start =
        renderBoxStart.localToGlobal(Offset.zero) & renderBoxStart.size;
    final endCenter = renderBoxEnd.localToGlobal(
      renderBoxEnd.size.center(Offset.zero),
    );
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return _FlightWidget(
          start: start.topLeft,
          end: endCenter,
          size: size,
          color: color,
          onEnd: () {
            entry.remove();
            if (onComplete != null) onComplete();
          },
        );
      },
    );
    overlay.insert(entry);
    final flight = _ActiveFlight(entry);
    _flights.add(flight);
  }
}

class _ActiveFlight {
  final OverlayEntry entry;
  _ActiveFlight(this.entry);
}

class _FlightWidget extends StatefulWidget {
  final Offset start;
  final Offset end;
  final double size;
  final Color color;
  final VoidCallback onEnd;
  const _FlightWidget({
    required this.start,
    required this.end,
    required this.size,
    required this.color,
    required this.onEnd,
  });

  @override
  State<_FlightWidget> createState() => _FlightWidgetState();
}

class _FlightWidgetState extends State<_FlightWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad);
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        widget.onEnd();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) {
          final t = _curve.value;
          final x = lerpDouble(
            widget.start.dx,
            widget.end.dx - widget.size / 2,
            t,
          )!;
          final yStart = widget.start.dy;
          final yEnd = widget.end.dy - widget.size / 2;
          final y =
              lerpDouble(yStart, yEnd, t)! - 60 * (t * (1 - t)); // slight arc
          final scale = (1 - t).clamp(0.4, 1.0);
          final opacity = (1 - t).clamp(0.0, 1.0);
          return Positioned(
            left: x,
            top: y,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
