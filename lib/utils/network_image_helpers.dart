import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Central helpers for consistent network image behavior across the app.
/// Goals:
///  - Contain (not crop) product imagery so users see the whole item.
///  - Provide lightweight shimmer / placeholder while loading.
///  - Cache images (via cached_network_image) for scroll performance.
///  - Graceful, consistent error & empty states.
///  - (Future) Hook for analytics / error logging in one place.

String sanitizeImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  var u = url.trim();
  // Example normalizations (extend as needed):
  // Remove accidental whitespace, enforce https, strip size params duplicates.
  if (u.startsWith('http://')) {
    u = 'https://${u.substring(7)}';
  }
  return u;
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.borderRadius});
  final BorderRadius borderRadius;
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFF222222)),
              FractionallySizedBox(
                widthFactor: 0.6,
                alignment: Alignment(-1 + 2 * _ac.value, 0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1, -0.2),
                      end: Alignment(1, 0.2),
                      colors: [
                        Color(0x002a2a2a),
                        Color(0x443a3a3a),
                        Color(0x002a2a2a),
                      ],
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

Widget _errorPlaceholder({double iconSize = 32, Color? accent}) =>
    _PlaceholderShell(
      icon: Icons.broken_image,
      iconSize: iconSize,
      accent: accent,
    );

Widget _emptyPlaceholder({double iconSize = 32, Color? accent}) =>
    _PlaceholderShell(
      icon: Icons.image_not_supported,
      iconSize: iconSize,
      accent: accent,
    );

/// Grid / list thumbnail (small) – contains the full image with optional letterboxing.
class ContainedNetworkThumb extends StatelessWidget {
  const ContainedNetworkThumb({
    super.key,
    required this.url,
    this.accent,
    this.fadeIn = true,
    this.fadeInDuration,
    this.alignment,
  });
  final String url;
  final Color? accent;
  // Allow callers to disable fade-in to avoid perceived layout/spacing shifts.
  final bool fadeIn;
  final Duration? fadeInDuration;
  // Let callers control alignment (e.g., bottomCenter to avoid letterbox gap under image).
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final clean = sanitizeImageUrl(url);
    if (clean.isEmpty) return _emptyPlaceholder(accent: accent);
    final dur = fadeIn
        ? (fadeInDuration ?? const Duration(milliseconds: 200))
        : Duration.zero;
    return CachedNetworkImage(
      imageUrl: clean,
      fit: BoxFit.contain,
      alignment: (alignment is Alignment)
          ? alignment as Alignment
          : Alignment.center,
      fadeInDuration: dur,
      memCacheWidth: 300, // hint – grid sized
      placeholder: (_, __) =>
          const _Shimmer(borderRadius: BorderRadius.all(Radius.circular(10))),
      errorWidget: (_, __, ___) => _errorPlaceholder(accent: accent),
    );
  }
}

/// Large detail image with zoom on tap.
class ProductDetailImage extends StatelessWidget {
  const ProductDetailImage({super.key, required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final clean = sanitizeImageUrl(url);
    if (clean.isEmpty) return _emptyPlaceholder(iconSize: 48);
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (c) => Dialog(
            backgroundColor: Colors.black,
            child: InteractiveViewer(
              maxScale: 6,
              child: CachedNetworkImage(
                imageUrl: clean,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => _errorPlaceholder(iconSize: 64),
              ),
            ),
          ),
        );
      },
      child: CachedNetworkImage(
        imageUrl: clean,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const _Shimmer(borderRadius: BorderRadius.all(Radius.circular(16))),
        errorWidget: (_, __, ___) => _errorPlaceholder(iconSize: 48),
      ),
    );
  }
}

class _PlaceholderShell extends StatelessWidget {
  const _PlaceholderShell({
    required this.icon,
    required this.iconSize,
    this.accent,
  });
  final IconData icon;
  final double iconSize;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final c = accent ?? Colors.white38;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black,
            (accent ?? Colors.grey).withValues(alpha: 0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: c, size: iconSize),
      ),
    );
  }
}
