import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:rapidrun_driver/theme/design_tokens.dart';

/// RadialAvailabilityMenu
/// Appears around the AvailabilityOrb on long press providing quick actions
/// for availability adjustments. Animated fan-out of action pods.
class RadialAvailabilityMenu extends StatefulWidget {
  final bool online;
  final Duration? remaining;
  final VoidCallback onClose;
  final VoidCallback onGoOffline;
  final VoidCallback onGoOnline;
  final VoidCallback onRemoveCap;
  final void Function(Duration add) onExtend;

  const RadialAvailabilityMenu({
    super.key,
    required this.online,
    required this.remaining,
    required this.onClose,
    required this.onGoOffline,
    required this.onGoOnline,
    required this.onRemoveCap,
    required this.onExtend,
  });

  @override
  State<RadialAvailabilityMenu> createState() => _RadialAvailabilityMenuState();
}

class _RadialAvailabilityMenuState extends State<RadialAvailabilityMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _scale = Tween(begin: .6, end: 1.0).animate(curve);
    _fade = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Backdrop + radial items
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: FadeTransition(
          opacity: _fade,
          child: Stack(
            children: [
              // Dim layer
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(.05),
                      Colors.black.withOpacity(.40),
                    ],
                  ),
                ),
              ),
              // Radial cluster aligned with orb (approx offset)
              _buildRadials(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadials(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    // Estimated orb center based on its Positioned parent offset.
    double baseCenterY = safeTop + 40 + 54;
    // If device has a tall notch / status ( > 44 ), push fan downward slightly.
    if (safeTop > 44) baseCenterY += (safeTop - 44) * 0.6;
    // When there are many actions (5) we nudge the center further down so the top-most pod stays clear.
    final actionsCount = widget.online ? (widget.remaining != null ? 5 : 4) : 1;
    if (actionsCount >= 5) baseCenterY += 12;
    final center = Offset(media.size.width / 2, baseCenterY);
    final radius = 110.0; // slightly reduced to tighten footprint

    final actions = <_RadialAction>[];
    if (widget.online) {
      actions.addAll([
        _RadialAction(
          icon: Icons.timer_outlined,
          label: '+30m',
          onTap: () => widget.onExtend(const Duration(minutes: 30)),
        ),
        _RadialAction(
          icon: Icons.hourglass_bottom,
          label: '+1h',
          onTap: () => widget.onExtend(const Duration(hours: 1)),
        ),
        _RadialAction(
          icon: Icons.timelapse_rounded,
          label: '+2h',
          onTap: () => widget.onExtend(const Duration(hours: 2)),
        ),
        if (widget.remaining != null)
          _RadialAction(
            icon: Icons.unfold_more_double,
            label: 'No Cap',
            onTap: widget.onRemoveCap,
          ),
        _RadialAction(
          icon: Icons.power_settings_new,
          label: 'Go Off',
          onTap: widget.onGoOffline,
        ),
      ]);
    } else {
      actions.add(
        _RadialAction(
          icon: Icons.play_arrow_rounded,
          label: 'Go Online',
          onTap: widget.onGoOnline,
        ),
      );
    }

    // Distribute angles in a downward fan (now narrower to reduce vertical excursion)
    final startDeg = 205.0;
    final endDeg = 335.0;
    final count = actions.length;
    final step = count == 1 ? 0 : (endDeg - startDeg) / (count - 1);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Stack(
              children: [
                for (int i = 0; i < actions.length; i++)
                  _positionedAction(
                    center,
                    radius * _scale.value,
                    (startDeg + step * i) * math.pi / 180,
                    actions[i],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _positionedAction(
    Offset center,
    double r,
    double theta,
    _RadialAction action,
  ) {
    final dx = center.dx + r * math.cos(theta);
    final dy = center.dy + r * math.sin(theta);
    return Positioned(
      left: dx - 36,
      top: dy - 36,
      width: 72,
      height: 72,
      child: _ActionPod(
        action: action,
        onTap: () {
          action.onTap();
          widget.onClose();
        },
        appear: _fade.value,
      ),
    );
  }
}

class _RadialAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _RadialAction({required this.icon, required this.label, required this.onTap});
}

class _ActionPod extends StatelessWidget {
  final _RadialAction action;
  final VoidCallback onTap;
  final double appear; // 0..1
  const _ActionPod({
    required this.action,
    required this.onTap,
    required this.appear,
  });
  @override
  Widget build(BuildContext context) {
    final bg = LinearGradient(
      colors: [
        DesignTokens.primary.withOpacity(.9),
        DesignTokens.secondary.withOpacity(.85),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Opacity(
      opacity: appear,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: bg,
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(.22), width: 1),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
