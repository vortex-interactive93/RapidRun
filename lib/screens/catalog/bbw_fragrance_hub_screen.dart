// File: lib/screens/catalog/bbw_fragrance_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun/screens/catalog/store_aisle_screen.dart';

class BbwFragranceHubScreen extends StatelessWidget {
  const BbwFragranceHubScreen({super.key});

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
              'Fragrance Department',
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
              'Browse in-store physical inventory',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Card 1: ALL FRAGRANCES (Hero Card - 158 SKUs)
            _buildSubCategoryCard(
              context,
              title: 'All Fragrances',
              subtitle: 'Complete in-store collection: Mists, Perfumes, Colognes & Sprays',
              countBadge: '158 IN-STORE SKUS',
              icon: Icons.all_inclusive,
              isHero: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      department: 'All Fragrances',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 2: Body Sprays & Mists (100 In-Store SKUs)
            _buildSubCategoryCard(
              context,
              title: 'Body Sprays & Mists',
              subtitle: 'Fine Fragrance Mists, Diamond Shimmer & Deodorizing Sprays',
              countBadge: '100 IN-STORE SKUS',
              icon: Icons.shower_outlined,
              isHero: false,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      subCategory: 'Body Sprays & Mists',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 3: Perfume & Cologne (58 In-Store SKUs)
            _buildSubCategoryCard(
              context,
              title: 'Perfume & Cologne',
              subtitle: 'Fine Eau de Parfum, Mini Rollerballs, Luxury Colognes & Travel Sprays',
              countBadge: '58 IN-STORE SKUS',
              icon: Icons.auto_awesome,
              isHero: false,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      subCategory: 'Perfume & Cologne',
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
    bool isHero = false,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFE5A93C);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
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
            const SizedBox(width: 16),
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
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 13),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.25),
                  ),
                  const SizedBox(height: 8),
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
