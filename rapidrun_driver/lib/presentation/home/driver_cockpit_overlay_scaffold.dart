// File: rapidrun_driver/lib/presentation/home/driver_cockpit_overlay_scaffold.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/radar/surge_radar_bar.dart';
import '../../widgets/order/slide_to_accept_order.dart';

class DriverCockpitOverlayScaffold extends StatefulWidget {
  final Widget mapCanvas;
  final Widget topFlightDeck;
  final Map<String, dynamic>? activeOffer;
  final Future<void> Function(String orderId) onAcceptOffer;
  final VoidCallback onDeclineOffer;

  const DriverCockpitOverlayScaffold({
    super.key,
    required this.mapCanvas,
    required this.topFlightDeck,
    this.activeOffer,
    required this.onAcceptOffer,
    required this.onDeclineOffer,
  });

  @override
  State<DriverCockpitOverlayScaffold> createState() => _DriverCockpitOverlayScaffoldState();
}

class _DriverCockpitOverlayScaffoldState extends State<DriverCockpitOverlayScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _offerAnimController;
  late final Animation<Offset> _sheetSlideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _offerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _sheetSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _offerAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _offerAnimController,
      curve: Curves.easeOut,
    );

    if (widget.activeOffer != null) {
      _offerAnimController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant DriverCockpitOverlayScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeOffer != null && oldWidget.activeOffer == null) {
      HapticFeedback.heavyImpact();
      _offerAnimController.forward(from: 0.0);
    } else if (widget.activeOffer == null && oldWidget.activeOffer != null) {
      _offerAnimController.reverse();
    }
  }

  @override
  void dispose() {
    _offerAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Dark Vector Map Canvas
        widget.mapCanvas,

        // 2. Persistent Top Telemetry Bar
        widget.topFlightDeck,

        // 3. Persistent Ambient Demand & Surge Radar Bar
        const Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: RepaintBoundary(
            child: SurgeRadarVisualizer(
              surgeMultiplier: 2.50,
              activeZone: 'Westover Village',
            ),
          ),
        ),

        // 4. Elevated Batch Offer HUD (Floats directly above the Radar)
        if (widget.activeOffer != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 210, // Rests 18px above the ~192px Surge Radar Deck
            child: SlideTransition(
              position: _sheetSlideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _FloatingBatchOfferCard(
                  offer: widget.activeOffer!,
                  onAccept: () => widget.onAcceptOffer(widget.activeOffer!['orderId']),
                  onDecline: widget.onDeclineOffer,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FloatingBatchOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Future<void> Function() onAccept;
  final VoidCallback onDecline;

  const _FloatingBatchOfferCard({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);
    final double guaranteedPayout = (offer['guaranteedPayout'] as num?)?.toDouble() ?? 15.68;
    final double tipAmount = (offer['customerTip'] as num?)?.toDouble() ?? 5.00;
    final double totalMiles = (offer['totalMiles'] as num?)?.toDouble() ?? 3.8;
    final int itemCount = (offer['itemCount'] as num?)?.toInt() ?? 1;
    final String storeName = offer['storeName'] ?? 'Bath & Body Works';
    final String storeAddress = offer['storeAddress'] ?? 'Westover Village, Fort Worth, TX';
    final String customerAddress = offer['customerAddress'] ?? '9009 White Settlement Rd';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF14171E).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: gold.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Guaranteed Payout, Tip Badge, Countdown Ring
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${guaranteedPayout.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Includes \$${tipAmount.toStringAsFixed(2)} Tip',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 30s Visual Ring
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 2.0),
                    ),
                    child: const Center(
                      child: Text(
                        '30',
                        style: TextStyle(
                          color: gold,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${totalMiles.toStringAsFixed(1)} mi total · $itemCount items to pick',
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),

              // Waypoint Hierarchy
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.storefront_rounded, color: gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PICK ITEMS',
                                style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        Text(storeAddress, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Customer Residence',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DELIVER',
                                style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        Text(customerAddress, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Row: Single-Line Decline & Offset Slide Track
              Row(
                children: [
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B1E26),
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onDecline();
                      },
                      child: const Text(
                        'Decline',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SlideToAcceptOrder(
                      label: 'SLIDE TO ACCEPT BATCH',
                      onAccepted: onAccept,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
