// File: rapidrun_driver/lib/widgets/stage_sheet/incoming_offer_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../order/slide_to_accept_order.dart';

class IncomingOfferSheet extends StatefulWidget {
  final String orderId;
  final String storeName;
  final String storeAddress;
  final String customerAddress;
  final double guaranteedPayout;
  final double includedTip;
  final double totalMiles;
  final int itemCount;
  final int expirationSeconds;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingOfferSheet({
    super.key,
    required this.orderId,
    required this.storeName,
    required this.storeAddress,
    required this.customerAddress,
    required this.guaranteedPayout,
    required this.includedTip,
    required this.totalMiles,
    required this.itemCount,
    this.expirationSeconds = 25,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingOfferSheet> createState() => _IncomingOfferSheetState();
}

class _IncomingOfferSheetState extends State<IncomingOfferSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timerController;
  Timer? _ticker;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.expirationSeconds;

    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.expirationSeconds),
    )..forward();

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDecline();
      }
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining > 0) {
        setState(() => _remaining--);
        if (_remaining <= 5) HapticFeedback.selectionClick();
      } else {
        t.cancel();
      }
    });

    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _timerController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const bg = Color(0xFF161616);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: gold.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Payout Row & Countdown Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${widget.guaranteedPayout.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: gold,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2618),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF4ADE80)),
                        ),
                        child: Text(
                          'Includes \$${widget.includedTip.toStringAsFixed(2)} Tip',
                          style: const TextStyle(
                            color: Color(0xFF86EFAC),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.totalMiles.toStringAsFixed(1)} mi total • ${widget.itemCount} items to pick',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Countdown Ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: AnimatedBuilder(
                      animation: _timerController,
                      builder: (context, _) => CircularProgressIndicator(
                        value: 1.0 - _timerController.value,
                        strokeWidth: 4,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                          _remaining <= 7 ? Colors.redAccent : gold,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '$_remaining',
                    style: TextStyle(
                      color: _remaining <= 7 ? Colors.redAccent : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // Waypoints
          _waypointRow(
            icon: Icons.storefront_rounded,
            iconColor: gold,
            title: widget.storeName,
            subtitle: widget.storeAddress,
            tag: 'PICK ITEMS',
          ),
          const Padding(
            padding: EdgeInsets.only(left: 17),
            child: SizedBox(
              height: 18,
              child: VerticalDivider(color: Colors.white24, thickness: 1.5),
            ),
          ),
          _waypointRow(
            icon: Icons.location_on_rounded,
            iconColor: Colors.lightBlueAccent,
            title: 'Customer Residence',
            subtitle: widget.customerAddress,
            tag: 'DELIVER',
          ),

          const SizedBox(height: 22),

          // Action Controls: Decline vs. Spring-Loaded Slide to Accept
          Row(
            children: [
              SizedBox(
                height: 60,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onDecline();
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF14171D),
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SlideToAcceptOrder(
                  label: 'SLIDE TO ACCEPT BATCH',
                  onAccepted: () async {
                    widget.onAccept();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waypointRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String tag,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
