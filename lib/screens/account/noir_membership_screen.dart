// File: lib/screens/account/noir_membership_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoirMembershipScreen extends StatefulWidget {
  final String currentTier;

  const NoirMembershipScreen({
    super.key,
    this.currentTier = 'Noir VIP',
  });

  @override
  State<NoirMembershipScreen> createState() => _NoirMembershipScreenState();
}

class _NoirMembershipScreenState extends State<NoirMembershipScreen> {
  late PageController _pageController;
  int _selectedTierIndex = 2; // Default to Noir VIP

  final List<Map<String, dynamic>> _tiers = [
    {
      'title': 'RapidRun Classic',
      'price': 'Free',
      'period': 'forever',
      'tagline': 'Standard pay-as-you-go delivery',
      'color': const Color(0xFF94A3B8),
      'perks': [
        'Standard \$3.99 Concierge Fee',
        'Standard Dispatch Queue',
        'Standard Catalog Access',
      ],
    },
    {
      'title': 'Velocity Pass',
      'price': '\$9.99',
      'period': '/ month',
      'tagline': 'Essential savings for regular orders',
      'color': const Color(0xFF10B981),
      'perks': [
        '\$0 Delivery on orders \$20+',
        'Reduced 2.5% Service Fee',
        'Priority Courier Matching',
        'Surge Shield Protection',
      ],
    },
    {
      'title': 'Noir VIP',
      'price': '\$19.99',
      'period': '/ month',
      'tagline': 'White-glove executive shopping concierge',
      'color': const Color(0xFFE5A93C),
      'perks': [
        '\$0 Delivery Fees on ALL orders',
        '0% Platform Service Fees',
        'Priority Fleet Tap (Top 5★ Drivers First)',
        'Single-Run Only (Never Batched with Others)',
        'Direct Private Shopper Hotline',
        'Exclusive Obsidian Titanium Theme',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTierIndex, viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _activateTier(String tierName) async {
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(tierName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CONCIERGE TIERS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              'SELECT YOUR FLIGHT LEVEL',
              style: TextStyle(
                color: const Color(0xFFE5A93C).withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Upgrade dispatch speed and eliminate service fees',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _tiers.length,
                onPageChanged: (idx) {
                  setState(() => _selectedTierIndex = idx);
                  HapticFeedback.selectionClick();
                },
                itemBuilder: (context, idx) {
                  final tier = _tiers[idx];
                  final isCurrent = tier['title'] == widget.currentTier;
                  final isSelected = _selectedTierIndex == idx;

                  return AnimatedScale(
                    scale: isSelected ? 1.0 : 0.94,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: _buildTierCard(tier, isCurrent),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildActionFooter(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tier, bool isCurrent) {
    final Color accentColor = tier['color'] as Color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14171D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tier['title'] as String,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tier['tagline'] as String,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      tier['price'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tier['period'] as String,
                      style: const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 32),
                Expanded(
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (tier['perks'] as List<String>).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final perk = (tier['perks'] as List<String>)[i];
                      return Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: accentColor, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              perk,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionFooter() {
    final active = _tiers[_selectedTierIndex];
    final isCurrent = active['title'] == widget.currentTier;
    final Color accentColor = active['color'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isCurrent ? Colors.white12 : accentColor,
          foregroundColor: isCurrent ? Colors.white70 : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isCurrent ? 0 : 4,
        ),
        onPressed: isCurrent ? null : () => _activateTier(active['title'] as String),
        child: Text(
          isCurrent ? 'CURRENT MEMBERSHIP' : 'UPGRADE TO ${active['title'].toString().toUpperCase()}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
