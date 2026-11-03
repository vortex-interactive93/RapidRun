// File: rapidrun_driver/lib/widgets/order/transparent_batch_offer_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/route_polyline_service.dart';
import 'slide_to_accept_order.dart';

class TransparentBatchOfferCard extends StatefulWidget {
  final Map<String, dynamic> offer;
  final ValueChanged<DriverRoutingPreference> onPreferenceChanged;
  final Future<void> Function() onAccept;
  final VoidCallback onDecline;

  const TransparentBatchOfferCard({
    super.key,
    required this.offer,
    required this.onPreferenceChanged,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<TransparentBatchOfferCard> createState() => _TransparentBatchOfferCardState();
}

class _TransparentBatchOfferCardState extends State<TransparentBatchOfferCard> {
  DriverRoutingPreference _activePref = DriverRoutingPreference.ecoFriendly;
  bool _showBreakdown = false;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);
    const green = Color(0xFF00E676);

    final double guaranteedPayout =
        (widget.offer['guaranteedPayout'] as num?)?.toDouble() ?? 15.68;
    final double tipAmount =
        (widget.offer['customerTip'] as num?)?.toDouble() ?? 5.00;
    final double totalMiles =
        (widget.offer['totalMiles'] as num?)?.toDouble() ?? 3.8;
    final int itemCount =
        (widget.offer['itemCount'] as num?)?.toInt() ?? 1;
    final String storeName = widget.offer['storeName'] ?? 'Bath & Body Works';
    final String storeAddress =
        widget.offer['storeAddress'] ?? 'Westover Village, Fort Worth, TX';
    final String customerAddress =
        widget.offer['customerAddress'] ?? '9009 White Settlement Rd';

    final basePay = (guaranteedPayout - tipAmount).clamp(0.0, guaranteedPayout);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF14171E).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: gold.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Payout Row & Countdown Timer (No Drag Handle)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showBreakdown = !_showBreakdown);
                    },
                    child: Row(
                      children: [
                        Text(
                          '\$${guaranteedPayout.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: gold,
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
                            color: green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Includes \$${tipAmount.toStringAsFixed(2)} Tip',
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                _showBreakdown
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: green,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 2.0),
                    ),
                    child: const Center(
                      child: Text(
                        '29',
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
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Animated Financial Breakdown Peeking
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1015),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('RapidRun Base Transit Pay:',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          Text('\$${basePay.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('100% Guaranteed Tip:',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          Text('+\$${tipAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: green, fontWeight: FontWeight.bold, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                crossFadeState: _showBreakdown ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              const SizedBox(height: 12),

              // 2. Waypoint Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.storefront_rounded, color: gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(storeAddress,
                            style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customer Residence',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(customerAddress,
                            style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Driver Routing Preference Filter Bar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1116),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    _buildRouteTab(
                      label: '🌱 Eco-Gas',
                      pref: DriverRoutingPreference.ecoFriendly,
                    ),
                    _buildRouteTab(
                      label: '⚡ Fastest',
                      pref: DriverRoutingPreference.fastestTraffic,
                    ),
                    _buildRouteTab(
                      label: '🛑 No Hwy',
                      pref: DriverRoutingPreference.avoidHighways,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Action Row (Decline & Slider Track)
              Row(
                children: [
                  SizedBox(
                    height: 58,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B1E26),
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(29),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onDecline();
                      },
                      child: const Text(
                        'Decline',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SlideToAcceptOrder(
                      label: 'SLIDE TO ACCEPT BATCH',
                      onAccepted: widget.onAccept,
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

  Widget _buildRouteTab({required String label, required DriverRoutingPreference pref}) {
    final isSelected = _activePref == pref;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activePref = pref);
          widget.onPreferenceChanged(pref);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE5A93C).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFE5A93C) : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFE5A93C) : Colors.white38,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
