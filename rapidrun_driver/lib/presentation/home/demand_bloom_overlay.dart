import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rapidrun_driver/theme/design_tokens.dart';

/// Represents a transient demand intensity cluster.
class DemandCluster {
  final LatLng center;
  final double radiusMeters; // visual radius scaling
  final double intensity; // 0-1
  final double ageSeconds; // for shimmer / pulse phase

  DemandCluster({
    required this.center,
    required this.radiusMeters,
    required this.intensity,
    required this.ageSeconds,
  });

  DemandCluster copyWith({double? ageSeconds}) => DemandCluster(
    center: center,
    radiusMeters: radiusMeters,
    intensity: intensity,
    ageSeconds: ageSeconds ?? this.ageSeconds,
  );
}

List<DemandCluster> mockDemandClusters(LatLng? anchor) {
  // Service area centroid (White Settlement TX focus)
  const centroid = LatLng(32.7568, -97.4768);
  final c = anchor == null
      ? centroid
      : LatLng(
          (anchor.latitude + centroid.latitude) / 2,
          (anchor.longitude + centroid.longitude) / 2,
        );
  return [
    DemandCluster(
      center: c,
      radiusMeters: 1400,
      intensity: 0.65,
      ageSeconds: 0,
    ),
  ];
}

/// Animated demand bloom overlay using additive radial gradients.
class DemandBloomOverlay extends StatefulWidget {
  final LatLng? cameraTarget;
  final bool visible;
  final double bottomInset; // pixels reserved for bottom panels
  const DemandBloomOverlay({
    super.key,
    required this.cameraTarget,
    this.visible = true,
    this.bottomInset = 0,
  });
  @override
  State<DemandBloomOverlay> createState() => _DemandBloomOverlayState();
}

class _DemandBloomOverlayState extends State<DemandBloomOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  List<DemandCluster> _clusters = [];

  @override
  void initState() {
    super.initState();
    _clusters = mockDemandClusters(widget.cameraTarget);
    _ctrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 4000),
          )
          ..addListener(_tick)
          ..repeat();
  }

  void _tick() {
    // Advance cluster ages for subtle pulsation (time accessible if needed via controller)
    setState(() {
      _clusters = _clusters
          .map((c) => c.copyWith(ageSeconds: (c.ageSeconds + 0.016) % 60))
          .toList();
    });
  }

  @override
  void didUpdateWidget(covariant DemandBloomOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraTarget != widget.cameraTarget &&
        widget.cameraTarget != null) {
      // Regenerate clusters near new anchor to give localized feel.
      _clusters = mockDemandClusters(widget.cameraTarget);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        opacity: widget.visible ? 0.85 : 0.0,
        child: CustomPaint(
          size: Size.infinite,
          painter: _BloomPainter(
            clusters: _clusters,
            bottomInset: widget.bottomInset,
          ),
        ),
      ),
    );
  }
}

class _BloomPainter extends CustomPainter {
  final List<DemandCluster> clusters;
  final double bottomInset;
  _BloomPainter({required this.clusters, required this.bottomInset});

  @override
  void paint(Canvas canvas, Size size) {
    if (clusters.isEmpty) return;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.fill;

    double minLat = clusters.map((c) => c.center.latitude).reduce(min);
    double maxLat = clusters.map((c) => c.center.latitude).reduce(max);
    double minLng = clusters.map((c) => c.center.longitude).reduce(min);
    double maxLng = clusters.map((c) => c.center.longitude).reduce(max);
    final latSpan = (maxLat - minLat).abs().clamp(0.00005, 1.0);
    final lngSpan = (maxLng - minLng).abs().clamp(0.00005, 1.0);
    final drawableHeight = size.height - bottomInset;

    for (final c in clusters) {
      final nx = (c.center.longitude - minLng) / lngSpan;
      final ny = (c.center.latitude - minLat) / latSpan;
      final center = Offset(
        nx * size.width,
        drawableHeight - ny * drawableHeight,
      );
      if (center.dy > drawableHeight) continue; // clip under inset
      final radius = (c.radiusMeters / 3000.0) * size.shortestSide * 0.65;

      final pulse = (sin((c.ageSeconds) * 0.6) + 1) * 0.5; // 0-1
      final intensity = (c.intensity * 0.6 + pulse * 0.4).clamp(0.0, 1.0);

      paint.shader = RadialGradient(
        colors: [
          DesignTokens.bloomCore.withOpacity(0.0),
          DesignTokens.bloomHot.withOpacity(0.55 * intensity),
          DesignTokens.bloomWarm.withOpacity(0.35 * intensity),
          DesignTokens.bloomCool.withOpacity(0.25 * intensity),
        ],
        stops: const [0.05, 0.25, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BloomPainter oldDelegate) =>
      oldDelegate.clusters != clusters;
}
