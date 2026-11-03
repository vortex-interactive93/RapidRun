// File: lib/screens/account/tier_features_deep_dive_screen.dart

import 'package:flutter/material.dart';

class TierFeaturesDeepDiveScreen extends StatelessWidget {
  const TierFeaturesDeepDiveScreen({super.key});

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
          'MEMBERSHIP SPECIFICATIONS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Value Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF241D14), Color(0xFF14171D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined, color: Color(0xFFE5A93C), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'RAPIDRUN MEMBERSHIP ENGINE',
                        style: TextStyle(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Designed for Transparency',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Compare how concierge delivery, platform fees, and driver dispatch algorithms scale across each flight tier.',
                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Feature Deep Dive Cards
            _buildDeepDiveCard(
              title: 'Concierge Delivery Fee',
              icon: Icons.local_shipping_outlined,
              description:
                  'Covers vehicle mileage, gas, and courier transit directly between the retail checkout counter and your doorstep.',
              classicValue: '\$3.99 flat per run',
              velocityValue: 'FREE on orders \$20+',
              noirValue: '100% FREE on ALL orders',
              highlightNoir: true,
            ),

            _buildDeepDiveCard(
              title: 'Platform Service Fee',
              icon: Icons.hub_outlined,
              description:
                  'Maintains cloud server routing, 24/7 support desks, and Stripe Treasury Just-In-Time fleet card authorizations.',
              classicValue: '5.0% of subtotal',
              velocityValue: '2.5% (50% Discount)',
              noirValue: '0.0% (Completely Waived)',
              highlightNoir: true,
            ),

            _buildDeepDiveCard(
              title: 'Dispatch Algorithm Pipeline',
              icon: Icons.bolt,
              description:
                  'Controls courier matching speed and how batch offers broadcast to nearby drivers.',
              classicValue: 'Standard 30s Radar Pool',
              velocityValue: 'Priority 15s Radar Match',
              noirValue: 'Priority Fleet Tap (Direct 5★ Match)',
              highlightNoir: true,
            ),

            _buildDeepDiveCard(
              title: 'Order Bundling Policy',
              icon: Icons.alt_route,
              description:
                  'Determines whether your courier picks up another customer’s order along the route.',
              classicValue: 'Standard Multi-Order Stacks',
              velocityValue: 'Max 2 Bundled Orders',
              noirValue: 'Dedicated Single-Run Only',
              highlightNoir: true,
            ),

            _buildDeepDiveCard(
              title: 'JIT Specialty Spend Buffer',
              icon: Icons.credit_card,
              description:
                  'Dynamic authorization buffer on the driver’s virtual MasterCard to cover substitutions and register tax variance.',
              classicValue: '15% Texas Tax Buffer',
              velocityValue: '15% Texas Tax Buffer',
              noirValue: '20% Extended VIP Buffer',
              highlightNoir: true,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDeepDiveCard({
    required String title,
    required IconData icon,
    required String description,
    required String classicValue,
    required String velocityValue,
    required String noirValue,
    bool highlightNoir = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE5A93C), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const Divider(color: Colors.white10, height: 24),
          _buildTierRow('RapidRun Classic', classicValue, Colors.white60),
          const SizedBox(height: 6),
          _buildTierRow('Velocity Pass (\$9.99/mo)', velocityValue, const Color(0xFF10B981)),
          const SizedBox(height: 6),
          _buildTierRow('Noir VIP (\$19.99/mo)', noirValue, const Color(0xFFE5A93C), isBold: highlightNoir),
        ],
      ),
    );
  }

  Widget _buildTierRow(String tier, String spec, Color specColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              tier,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              spec,
              style: TextStyle(
                color: specColor,
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                height: 1.3,
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
