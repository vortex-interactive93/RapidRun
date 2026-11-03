import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'stage_sheet_controller.dart';

/// Overlay widget that listens to a [StageSheetController] and renders the
/// appropriate sheet: single offer card, multi-offer stack, active order stub,
/// or post-delivery toast.
class StageSheet extends StatefulWidget {
  final StageSheetController controller;
  final EdgeInsets padding;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onPromote;
  final VoidCallback? onCompleteActiveOrder; // temporary for demo
  const StageSheet({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 28),
    this.onAccept,
    this.onDecline,
    this.onPromote,
    this.onCompleteActiveOrder,
  });

  @override
  State<StageSheet> createState() => _StageSheetState();
}

class _StageSheetState extends State<StageSheet> with TickerProviderStateMixin {
  late AnimationController _cinematic;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _cinematic = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scale = Tween(begin: .92, end: 1.0).animate(
      CurvedAnimation(parent: _cinematic, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _cinematic, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, .04), end: Offset.zero).animate(
      CurvedAnimation(parent: _cinematic, curve: Curves.easeOutCubic),
    );
    widget.controller.addListener(_onController);
  }

  void _onController() {
    final c = widget.controller;
    if (!c.cinematicPlayed && c.state == StageSheetState.singleOffer && c.offers.isNotEmpty) {
      c.cinematicPlayed = true;
      _cinematic.forward(from: 0);
    }
    setState(() {}); // minimal; rely on controller state changes
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _cinematic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c.state == StageSheetState.idle) return const SizedBox.shrink();

    Widget child;
    switch (c.state) {
      case StageSheetState.singleOffer:
        child = _SingleOfferCard(
          offer: c.offers.first,
          fade: _fade,
          scale: _scale,
          slide: _slide,
          onAccept: () {
            widget.onAccept?.call();
            c.acceptPrimary();
          },
          onDecline: () {
            widget.onDecline?.call();
            c.declinePrimary();
          },
        );
        break;
      case StageSheetState.multiOffer:
        child = _MultiOfferStack(
          offers: c.offers,
          onAccept: () {
            widget.onAccept?.call();
            c.acceptPrimary();
          },
          onDecline: () {
            widget.onDecline?.call();
            c.declinePrimary();
          },
          onPromote: (i) {
            c.promote(i);
            widget.onPromote?.call();
          },
        );
        break;
      case StageSheetState.activeOrder:
        child = _ActiveOrderStub(onComplete: () {
          c.completeActiveOrder();
          widget.onCompleteActiveOrder?.call();
        });
        break;
      case StageSheetState.postDelivery:
        child = const _PostDeliveryToast();
        break;
      case StageSheetState.idle:
        child = const SizedBox();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: widget.padding,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(c.state),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SingleOfferCard extends StatelessWidget {
  final OfferModel offer;
  final Animation<double> fade;
  final Animation<double> scale;
  final Animation<Offset> slide;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _SingleOfferCard({
    required this.offer,
    required this.fade,
    required this.scale,
    required this.slide,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          scale: scale,
          child: _OfferSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OfferHeader(payout: offer.payout, distance: offer.distanceMiles, items: offer.itemCount),
                const SizedBox(height: 12),
                _MetaRow(offer: offer),
                const SizedBox(height: 16),
                _PrimaryActions(onAccept: onAccept, onDecline: onDecline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiOfferStack extends StatelessWidget {
  final List<OfferModel> offers;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final ValueChanged<int> onPromote;
  const _MultiOfferStack({
    required this.offers,
    required this.onAccept,
    required this.onDecline,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final primary = offers.first;
    final second = offers.length > 1 ? offers[1] : null;
    final third = offers.length > 2 ? offers[2] : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (third != null)
          _PeekCard(
            offset: 32,
            scale: .88,
            onTap: () => onPromote(2),
          ),
        if (second != null)
          _PeekCard(
            offset: 16,
            scale: .94,
            onTap: () => onPromote(1),
          ),
        _OfferSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OfferHeader(payout: primary.payout, distance: primary.distanceMiles, items: primary.itemCount),
              const SizedBox(height: 12),
              _MetaRow(offer: primary),
              const SizedBox(height: 16),
              _PrimaryActions(onAccept: onAccept, onDecline: onDecline),
              const SizedBox(height: 8),
              if (offers.length > 1)
                Center(
                  child: Text('${offers.length - 1} more • tap peeks to preview',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferSurface extends StatelessWidget {
  final Widget child;
  const _OfferSurface({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(.08), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: child,
    );
  }
}

class _PeekCard extends StatelessWidget {
  final double offset;
  final double scale;
  final VoidCallback onTap;
  const _PeekCard({required this.offset, required this.scale, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: offset,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: onTap,
          child: IgnorePointer(
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(.05),
                    Colors.white.withOpacity(.02),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(.08),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferHeader extends StatelessWidget {
  final double payout;
  final double distance;
  final int items;
  const _OfferHeader({required this.payout, required this.distance, required this.items});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '\$${payout.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _Pill(icon: Icons.route, label: '${distance.toStringAsFixed(1)} mi'),
              _Pill(icon: Icons.inventory_2, label: '$items items'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final OfferModel offer;
  const _MetaRow({required this.offer});
  @override
  Widget build(BuildContext context) {
    final remaining = offer.expiresAt.difference(DateTime.now());
    final secs = remaining.inSeconds.clamp(0, 999);
    return Row(
      children: [
        _CountdownCircle(secondsRemaining: secs),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'ETA ${offer.eta.inMinutes}m • Payoff idx ${offer.payoffIndex.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _PrimaryActions({required this.onAccept, required this.onDecline});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Accept'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onDecline,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Decline'),
          ),
        ),
      ],
    );
  }
}

class _ActiveOrderStub extends StatelessWidget {
  final VoidCallback onComplete;
  const _ActiveOrderStub({required this.onComplete});
  @override
  Widget build(BuildContext context) {
    return _OfferSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active Order', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('In progress • prototype placeholder'),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onComplete,
              child: const Text('Complete (demo)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostDeliveryToast extends StatelessWidget {
  const _PostDeliveryToast();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(.08), width: 1),
        ),
        child: const Text('Delivery complete! Ready for the next offer.'),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _CountdownCircle extends StatefulWidget {
  final int secondsRemaining;
  const _CountdownCircle({required this.secondsRemaining});
  @override
  State<_CountdownCircle> createState() => _CountdownCircleState();
}

class _CountdownCircleState extends State<_CountdownCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.secondsRemaining.clamp(1, 60)),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _CountdownCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secondsRemaining != widget.secondsRemaining) {
      _controller.dispose();
      _controller = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.secondsRemaining.clamp(1, 60)),
      )..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = 1 - _controller.value;
          return CustomPaint(
            painter: _CountdownPainter(progress: progress),
            child: Center(
              child: Text(
                '${widget.secondsRemaining}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress; // 1 -> 0
  _CountdownPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 3.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final basePaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: const [Color(0xFFFFC857), Color(0xFFFF6F3C), Color(0xFFFFC857)],
        stops: const [0, .55, 1],
      ).createShader(rect)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, basePaint);
    final startAngle = -math.pi / 2;
    final sweepAngle = (2 * math.pi) * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter oldDelegate) => oldDelegate.progress != progress;
}
