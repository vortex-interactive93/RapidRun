import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../home/incoming_offer_overlay.dart';
import 'driver_stage_controller.dart';

/// Stage Sheet overlay that adapts presentation based on DriverStage.
class DriverStageSheet extends StatefulWidget {
  final DriverStageController controller;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCycle; // cycle forward in multi
  final VoidCallback? onOpenOffers; // open legacy sheet fallback (optional)
  const DriverStageSheet({
    super.key,
    required this.controller,
    this.onAccept,
    this.onDecline,
    this.onCycle,
    this.onOpenOffers,
  });

  @override
  State<DriverStageSheet> createState() => _DriverStageSheetState();
}

class _DriverStageSheetState extends State<DriverStageSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _cinematic;
  static int _buildCount = 0; // debug rebuild counter

  @override
  void initState() {
    super.initState();
    _cinematic = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _cinematic.dispose();
    super.dispose();
  }

  void _onChanged() {
    final st = widget.controller.state;
    // Trigger cinematic only first time a singleOffer appears and not yet played.
    if (st.stage == DriverStage.singleOffer && !st.firstCinematicPlayed) {
      _cinematic.forward(from: 0);
      // Mark played after forward completes (so we don't replay while animating)
      _cinematic.addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          widget.controller.markCinematicPlayed();
        }
      });
    }
    setState(() {}); // re-render
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      _buildCount++;
      if (_buildCount % 50 == 0) {
        // Every 50 builds emit a line so dev can gauge churn quickly.
        // (Use DevTools for precise profiling.)
        // ignore: avoid_print
        print('[Perf][StageSheet] rebuilds: $_buildCount');
      }
      return true;
    }());
    final st = widget.controller.state;
    if (st.stage == DriverStage.idle) {
      return const SizedBox.shrink();
    }
    final blur =
        st.stage == DriverStage.singleOffer && !st.firstCinematicPlayed;
    final dim = st.stage == DriverStage.singleOffer;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: st.stage == DriverStage.postDelivery,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: 1,
          child: Stack(
            children: [
              // Map dim + optional blur (first single offer only)
              if (dim)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 350),
                  opacity: 0.85,
                  child: Container(color: Colors.black.withOpacity(0.55)),
                ),
              if (blur)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: const SizedBox.expand(),
                ),
              _buildContent(context, st),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DriverStageState st) {
    switch (st.stage) {
      case DriverStage.singleOffer:
        return _buildSingle(context, st);
      case DriverStage.multiOffer:
        return _buildMulti(context, st);
      case DriverStage.activeOrder:
        return _buildActiveOrder(context, st);
      case DriverStage.postDelivery:
        return _buildPostDelivery(context);
      case DriverStage.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSingle(BuildContext context, DriverStageState st) {
    final offer = st.activeOffer!;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        child: AnimatedBuilder(
          animation: _cinematic,
          builder: (ctx, _) {
            final scale = Tween<double>(
              begin: 0.92,
              end: 1,
            ).transform(Curves.easeOutBack.transform(_cinematic.value));
            final opacity = CurvedAnimation(
              parent: _cinematic,
              curve: const Interval(0, .65, curve: Curves.easeOut),
            ).value;
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: _OfferHeroCard(
                  offer: offer,
                  onAccept: widget.onAccept,
                  onDecline: widget.onDecline,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMulti(BuildContext context, DriverStageState st) {
    final offers = st.offers;
    final active = st.activeOffer!;
    // Show up to 3 (active + 2 peeks)
    final peek = offers.skip(1).take(2).toList();
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 360,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (int i = peek.length - 1; i >= 0; i--) ...[
              _PeekCard(offer: peek[i], depth: i + 1, onTap: widget.onCycle),
            ],
            _OfferHeroCard(
              offer: active,
              onAccept: widget.onAccept,
              onDecline: widget.onDecline,
              activePositionLabel: '${st.activeIndex + 1}/${offers.length}',
              onCycle: widget.onCycle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrder(BuildContext context, DriverStageState st) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        child: _ActiveOrderPlaceholder(onView: () {}),
      ),
    );
  }

  Widget _buildPostDelivery(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 140),
        child: _PostDeliveryToast(),
      ),
    );
  }
}

class _OfferHeroCard extends StatelessWidget {
  final IncomingOfferData offer;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final String? activePositionLabel; // e.g. "1/2" for multi state
  final VoidCallback? onCycle; // cycle to next offer
  const _OfferHeroCard({
    required this.offer,
    this.onAccept,
    this.onDecline,
    this.activePositionLabel,
    this.onCycle,
  });
  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: MediaQuery.of(context).size.width * .92,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(.08)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  offer.store,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (activePositionLabel != null) ...[
                GestureDetector(
                  onTap: onCycle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activePositionLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.swap_horiz,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              _TinyCountdown(duration: offer.expiresIn),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dropoff: ${offer.dropoffArea}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Pay', ' ${offer.pay.toStringAsFixed(2)}'),
              _pill('Distance', '${offer.distanceMiles.toStringAsFixed(1)} mi'),
              _pill('ETA', '${offer.eta.inMinutes} min'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _action(
                  context,
                  label: 'Decline',
                  filled: false,
                  onTap: onDecline,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _action(
                  context,
                  label: 'Accept',
                  filled: true,
                  onTap: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onCycle != null) {
      return GestureDetector(
        onHorizontalDragEnd: (_) => onCycle?.call(),
        child: card,
      );
    }
    return card;
  }
}

class _PeekCard extends StatelessWidget {
  final IncomingOfferData offer;
  final int depth; // 1 = first behind hero
  final VoidCallback? onTap;
  const _PeekCard({required this.offer, required this.depth, this.onTap});
  @override
  Widget build(BuildContext context) {
    final scale = 1 - (depth * 0.06);
    final dy = depth * 26.0;
    return Positioned(
      bottom: 110 - dy,
      child: GestureDetector(
        onTap: onTap,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: MediaQuery.of(context).size.width * .75,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(.05)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.store,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${offer.pay.toStringAsFixed(2)} • ${offer.distanceMiles.toStringAsFixed(1)} mi',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveOrderPlaceholder extends StatelessWidget {
  final VoidCallback onView;
  const _ActiveOrderPlaceholder({required this.onView});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * .92,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.80),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Order',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Order progress + substitution preview coming soon.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _action(
              context,
              label: 'View Details',
              filled: true,
              onTap: onView,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostDeliveryToast extends StatefulWidget {
  @override
  State<_PostDeliveryToast> createState() => _PostDeliveryToastState();
}

class _PostDeliveryToastState extends State<_PostDeliveryToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final scale = Tween(
      begin: .92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(.08)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Text(
            'Delivery Complete 🎉',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// --- Shared atoms ---
Widget _pill(String label, String value) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(.06),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withOpacity(.08)),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
);

class _TinyCountdown extends StatefulWidget {
  final Duration duration;
  const _TinyCountdown({required this.duration});
  @override
  State<_TinyCountdown> createState() => _TinyCountdownState();
}

class _TinyCountdownState extends State<_TinyCountdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final remaining = widget.duration * (1 - t);
        final secs = remaining.inSeconds;
        final progress = 1 - t;
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CustomPaint(painter: _RingPainter(progress: progress)),
            ),
            Text(
              secs.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white24
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader =
          SweepGradient(
            colors: [Colors.orangeAccent, Colors.deepOrangeAccent],
            startAngle: -math.pi / 2,
            endAngle: -math.pi / 2 + (math.pi * 2 * progress),
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2),
              radius: size.width / 2,
            ),
          );
    final rect = Offset.zero & size;
    // Background
    canvas.drawArc(rect.deflate(2), 0, math.pi * 2, false, stroke);
    // Foreground
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

Widget _action(
  BuildContext context, {
  required String label,
  bool filled = true,
  VoidCallback? onTap,
}) => GestureDetector(
  onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: filled ? Colors.orangeAccent : Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: filled ? Colors.orangeAccent : Colors.white.withOpacity(.15),
      ),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.black : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    ),
  ),
);
