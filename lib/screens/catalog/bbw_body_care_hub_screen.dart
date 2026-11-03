// File: lib/screens/catalog/bbw_body_care_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun/screens/catalog/store_aisle_screen.dart';

class BbwBodyCareHubScreen extends StatelessWidget {
  const BbwBodyCareHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0E),
        elevation: 0,
        iconTheme: const IconThemeData(color: gold),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'BATH & BODY WORKS',
              style: TextStyle(
                color: gold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              'Body Care Department',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Subcategory',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Browse in-store moisturizers, washes & care',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 18),

            // HERO CARD: ALL BODY CARE (Browse Entire Department)
            _buildSubCategoryCard(
              context,
              title: 'All Body Care',
              subtitle: 'Explore the complete collection of lotions, scrubs, washes & minis',
              countBadge: 'ALL IN-STORE PRODUCTS',
              icon: Icons.all_inclusive,
              isHero: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Body Care',
                      department: 'All Body Care',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // CARD 1: MOISTURIZERS
            _buildSubCategoryCard(
              context,
              title: 'Moisturizers',
              subtitle: 'Daily Nourishing Lotions, Ultimate Hydration Creams & Body Butters',
              countBadge: 'HYDRATION ESSENTIALS',
              icon: Icons.water_drop_outlined,
              isHero: false,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Body Care',
                      department: 'Moisturizers',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // CARD 2: BATH & SHOWER
            _buildSubCategoryCard(
              context,
              title: 'Bath & Shower',
              subtitle: 'Shower Gels, Moisturizing Body Wash, Exfoliating Scrubs & Bar Soaps',
              countBadge: 'CLEANSING & BATH',
              icon: Icons.bathtub_outlined,
              isHero: false,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Body Care',
                      department: 'Bath & Shower',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // CARD 3: MINI & TRAVEL SIZE
            _buildSubCategoryCard(
              context,
              title: 'Mini & Travel Size',
              subtitle: 'TSA-Approved Travel Lotions, On-The-Go Body Washes & Hand Creams',
              countBadge: 'TRAVEL ESSENTIALS',
              icon: Icons.flight_takeoff_outlined,
              isHero: false,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Body Care',
                      department: 'Mini & Travel Size',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // CARD 4: LIP CARE
            _buildSubCategoryCard(
              context,
              title: 'Lip Care',
              subtitle: 'Nourishing Lip Glosses, Lip Balms, Lip Scrubs & Night Masks',
              countBadge: 'LIP TREATMENTS',
              icon: Icons.favorite_border,
              isHero: false,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Body Care',
                      department: 'Lip Care',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String countBadge,
    required IconData icon,
    required bool isHero,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFE5A93C);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF14171E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHero ? gold.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.06),
            width: isHero ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gold.withValues(alpha: isHero ? 0.45 : 0.2)),
              ),
              child: Icon(icon, color: gold, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 13),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    countBadge,
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
