import 'package:flutter/material.dart';
import '../services/favorites_cart_service.dart';
import '../utils/cart_flyer.dart';

/// External trigger for a subtle extra cart badge pulse (e.g. fly animation complete).
class CartBadgePulse {
  CartBadgePulse._();
  static final ValueNotifier<int> _notifier = ValueNotifier<int>(0);
  static void pulse() => _notifier.value++;
  static ValueNotifier<int> get notifier => _notifier;
}

/// A reusable cart icon with a reactive badge showing total quantity.
///
/// Usage inside an AppBar actions list:
///   ReactiveCartBadge(onPressed: () => Navigator.pushNamed(context, '/cart'))
class ReactiveCartBadge extends StatefulWidget {
  final VoidCallback onPressed;
  final Color iconColor;
  final double iconSize;
  final bool showZero;
  final EdgeInsets badgePadding;
  final Color badgeColor;
  final Duration pulseDuration;
  const ReactiveCartBadge({
    super.key,
    required this.onPressed,
    this.iconColor = const Color(0xFFe6b450),
    this.iconSize = 24,
    this.showZero = false,
    this.badgePadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.badgeColor = Colors.redAccent,
    this.pulseDuration = const Duration(milliseconds: 450),
  });

  @override
  State<ReactiveCartBadge> createState() => _ReactiveCartBadgeState();
}

class _ReactiveCartBadgeState extends State<ReactiveCartBadge>
    with TickerProviderStateMixin {
  final GlobalKey _iconKey = GlobalKey(debugLabel: 'cart_badge_anchor');
  late final AnimationController _controller; // main add pulse
  late final AnimationController _microController; // secondary subtle pulse
  int _lastTotal = 0;
  int _lastExternalPulse = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _microController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0,
      upperBound: 1,
    );
    // Defer registration until widget tree is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        CartFlyer.instance.registerCartAnchor(_iconKey);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _microController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([cart, CartBadgePulse.notifier]),
      builder: (_, __) {
        final total = cart.totalItems;
        if (total > _lastTotal) {
          // trigger pulse when adding items
          _controller
            ..reset()
            ..forward();
        }
        _lastTotal = total;
        // external micro pulse trigger
        final pulseCount = CartBadgePulse.notifier.value;
        if (pulseCount != _lastExternalPulse) {
          _microController
            ..reset()
            ..forward();
          _lastExternalPulse = pulseCount;
        }
        final showBadge = widget.showZero ? true : total > 0;
        final semanticLabel =
            'Cart, ' +
            (total == 0
                ? 'empty'
                : total == 1
                ? '1 item'
                : '$total items');
        final scaleMain = Tween(
          begin: 0.9,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_controller);
        final micro = CurvedAnimation(
          parent: _microController,
          curve: Curves.easeOut,
        );
        return Semantics(
          label: semanticLabel,
          button: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                key: _iconKey,
                tooltip: 'View cart',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(Icons.shopping_cart, size: widget.iconSize),
                color: widget.iconColor,
                onPressed: widget.onPressed,
              ),
              if (showBadge)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Semantics(
                    label: total == 0
                        ? 'No items'
                        : (total == 1
                              ? '1 item in cart'
                              : '$total items in cart'),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final mainFactor =
                            (scaleMain.value - 1) * (1 - _controller.value);
                        final microFactor = 0.12 * micro.value;
                        return Transform.scale(
                          scale: 1 + mainFactor + microFactor,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: widget.badgePadding,
                        decoration: BoxDecoration(
                          color: widget.badgeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          total > 99 ? '99+' : total.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
