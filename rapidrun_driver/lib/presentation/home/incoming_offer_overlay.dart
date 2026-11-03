import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:rapidrun_driver/theme/design_tokens.dart';

class IncomingOfferData {
  final String id;
  final String store;
  final String dropoffArea;
  final double pay; // dollars
  final double distanceMiles;
  final Duration eta;
  final Duration expiresIn;
  const IncomingOfferData({
    required this.id,
    required this.store,
    required this.dropoffArea,
    required this.pay,
    required this.distanceMiles,
    required this.eta,
    required this.expiresIn,
  });
}

class IncomingOfferOverlay extends StatefulWidget {
  final IncomingOfferData data;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onExpire;
  const IncomingOfferOverlay({
    super.key,
    required this.data,
    required this.onAccept,
    required this.onDecline,
    required this.onExpire,
  });

  @override
  State<IncomingOfferOverlay> createState() => _IncomingOfferOverlayState();
}

class _IncomingOfferOverlayState extends State<IncomingOfferOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller; // counts down

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.data.expiresIn,
    )..forward();
    _controller.addStatusListener((st) {
      if (st == AnimationStatus.completed) widget.onExpire();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _controller.value; // 0->1
    final remaining = widget.data.expiresIn * (1 - t);
    final secs = remaining.inSeconds;
    final progress = 1 - t;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 140,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Transform.scale(
              scale: 1 + math.sin(t * math.pi * 4) * 0.02,
              child: Container(
                width: MediaQuery.of(context).size.width * .90,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceElevated.withOpacity(.95),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(.06)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 28,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.data.store,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _CountdownRing(progress: progress, secs: secs),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dropoff: ${widget.data.dropoffArea}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _pill(
                          label: 'Pay',
                          value: '${widget.data.pay.toStringAsFixed(2)}',
                          color: DesignTokens.primary,
                        ),
                        const SizedBox(width: 8),
                        _pill(
                          label: 'Distance',
                          value:
                              '${widget.data.distanceMiles.toStringAsFixed(1)} mi',
                          color: DesignTokens.secondary,
                        ),
                        const SizedBox(width: 8),
                        _pill(
                          label: 'ETA',
                          value: '${widget.data.eta.inMinutes} min',
                          color: DesignTokens.available,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            context,
                            label: 'Decline',
                            filled: false,
                            onTap: widget.onDecline,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _actionButton(
                            context,
                            label: 'Accept',
                            filled: true,
                            onTap: widget.onAccept,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.1,
              color: Colors.white60,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(.55)],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: filled
              ? LinearGradient(
                  colors: [DesignTokens.primary, DesignTokens.secondary],
                )
              : null,
          color: filled ? null : Colors.white.withOpacity(.06),
          border: Border.all(color: Colors.white.withOpacity(.10), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final double progress;
  final int secs;
  const _CountdownRing({required this.progress, required this.secs});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CountdownPainter(progress: progress),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Text(
            '$secs',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress;
  const _CountdownPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white12;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.4
      ..shader = SweepGradient(
        colors: [DesignTokens.secondaryBright, DesignTokens.primaryBright],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(Rect.fromCircle(center: c, radius: r + 2));
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter old) =>
      old.progress != progress;
}
