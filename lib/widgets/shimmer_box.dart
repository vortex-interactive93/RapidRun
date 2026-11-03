import 'package:flutter/material.dart';

/// Lightweight shimmer effect without external packages.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shimmerPosition = _controller.value * 2 - 0.5; // range -0.5..1.5
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _ShimmerPainter(shimmerPosition),
          ),
        );
      },
    );
  }
}

/// A realistic Skeleton Product Card placeholder while product catalogs load.
class ProductCardShimmer extends StatelessWidget {
  final double width;
  final double height;
  const ProductCardShimmer({
    super.key,
    this.width = 140,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          Expanded(
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),
          // Title skeleton line
          ShimmerBox(
            width: width * 0.8,
            height: 12,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          // Subtitle skeleton line
          ShimmerBox(
            width: width * 0.5,
            height: 10,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          // Price skeleton tag
          ShimmerBox(
            width: width * 0.4,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double pos; // -0.5 .. 1.5
  _ShimmerPainter(this.pos);
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF2A2A2A),
          const Color(0xFF262626),
          const Color(0xFF2A2A2A),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);
    // Shimmer band
    final bandWidth = size.width * 0.6;
    final startX = (pos * (size.width + bandWidth)) - bandWidth;
    final rect = Rect.fromLTWH(startX, 0, bandWidth, size.height);
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.05, 0.5, 0.95],
      ).createShader(rect);
    canvas.drawRect(rect, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.pos != pos;
}
