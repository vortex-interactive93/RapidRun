// File: packages/rapidrun_shared/lib/widgets/rapid_network_image.dart

import 'package:flutter/material.dart';

class RapidNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const RapidNetworkImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return _IsolatedShimmerPlaceholder(width: width, height: height);
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: const Color(0xFF1E1E1E),
            child: Icon(
              Icons.inventory_2_outlined,
              color: Colors.white.withValues(alpha: 0.3),
              size: 28.0,
            ),
          );
        },
      ),
    );
  }
}

class _IsolatedShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;

  const _IsolatedShimmerPlaceholder({
    required this.width,
    required this.height,
  });

  @override
  State<_IsolatedShimmerPlaceholder> createState() => _IsolatedShimmerPlaceholderState();
}

class _IsolatedShimmerPlaceholderState extends State<_IsolatedShimmerPlaceholder>
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
    // RepaintBoundary isolates the shimmer wave from triggering parent rebuilds
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  (_controller.value - 0.3).clamp(0.0, 1.0),
                  _controller.value.clamp(0.0, 1.0),
                  (_controller.value + 0.3).clamp(0.0, 1.0),
                ],
                colors: const [
                  Color(0xFF1C1C1E),
                  Color(0xFF2C2C2E),
                  Color(0xFF1C1C1E),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
