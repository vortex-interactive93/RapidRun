// File: lib/screens/catalog/bbw_store_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun/screens/catalog/bbw_fragrance_hub_screen.dart';
import 'package:rapidrun/screens/catalog/bbw_body_care_hub_screen.dart';
import 'package:rapidrun/screens/catalog/store_aisle_screen.dart';
import '../storefronts/bbw_aura_storefront.dart';
import '../../services/product_catalog_service.dart';

class BbwStoreScreen extends StatelessWidget {
  const BbwStoreScreen({super.key});

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
              'IN-STORE CATALOG',
              style: TextStyle(
                color: gold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              'Bath & Body Works',
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
              'Store Departments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a category to browse physical in-store inventory',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 18),

            // HERO: SCENT AURA DISCOVERY
            _buildCategoryCard(
              context,
              title: 'Discover Scent Auras',
              subtitle: 'Warm & Cozy, Fresh Woods, Fruity Sparkle & Floral Escape',
              badgeText: 'INSTANT SENSORY DISCOVERY',
              badgeColor: const Color(0xFF3B82F6),
              icon: Icons.auto_awesome_rounded,
              isActive: true,
              onTap: () async {
                HapticFeedback.lightImpact();
                await ProductCatalogService.instance.ensureLoaded();
                final allBBW = ProductCatalogService.instance
                    .all()
                    .where((p) => (p.store ?? '').toLowerCase().contains('bath') || (p.brand ?? '').toLowerCase().contains('bath'))
                    .toList();

                if (context.mounted) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: true,
                      pageBuilder: (context, animation, secondaryAnimation) => BBWAuraStorefront(allProducts: allBBW),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 220),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            // 1. ACTIVE: FRAGRANCE (UNLOCKED & LIVE)
            _buildCategoryCard(
              context,
              title: 'Fragrance',
              subtitle: 'Fine Fragrance Mists, Perfumes, Colognes & Rollerballs',
              badgeText: '139 IN-STORE SKUS',
              badgeColor: gold,
              icon: Icons.auto_awesome,
              isActive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BbwFragranceHubScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // 2. ACTIVE: BODY CARE (UNLOCKED & LIVE)
            _buildCategoryCard(
              context,
              title: 'Body Care',
              subtitle: 'Moisturizers, Bath & Shower, Minis & Lip Care',
              badgeText: 'IN-STORE CATALOG',
              badgeColor: gold,
              icon: Icons.spa_outlined,
              isActive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BbwBodyCareHubScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // 3. CANDLES (UNLOCKED & LIVE)
            _buildCategoryCard(
              context,
              title: 'Candles',
              subtitle: '3-Wick, Single-Wick, 4-Wick & Pedestals',
              badgeText: 'FULL COLLECTION',
              badgeColor: const Color(0xFF00E676),
              icon: Icons.local_fire_department_outlined,
              isActive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Candles',
                      department: 'All Candles',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 4. WALLFLOWERS & DIFFUSERS (UNLOCKED & LIVE)
            _buildCategoryCard(
              context,
              title: 'Wallflowers & Diffusers',
              subtitle: 'Home Fragrance Refills, Scent Plugs & Room Sprays',
              badgeText: '100+ IN-STORE SKUS',
              badgeColor: const Color(0xFF00E676),
              icon: Icons.home_outlined,
              isActive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Wallflowers & Diffusers',
                      department: 'Wallflowers',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 5. HAND SOAPS & SANITIZERS (UNLOCKED & LIVE)
            _buildCategoryCard(
              context,
              title: 'Hand Soaps & Sanitizers',
              subtitle: 'Foaming Soaps, Gel Soaps & PocketBac Sanitizers',
              badgeText: 'IN-STORE CATALOG',
              badgeColor: gold,
              icon: Icons.clean_hands_outlined,
              isActive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Hand Soaps & Sanitizers',
                      department: 'All Hand Soaps',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 6. THE MEN'S SHOP (UNLOCKED & LIVE)
            _buildCategoryCard(
              context,
              title: "The Men's Shop",
              subtitle: '3-in-1 Wash, Colognes, Deodorants & Grooming',
              badgeText: '100+ IN-STORE SKUS',
              badgeColor: gold,
              icon: Icons.man_outlined,
              isActive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: "The Men's Shop",
                      department: "The Men's Shop",
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 7. HOME CARE (UNLOCKED & LIVE)
            _buildCategoryCard(
              context,
              title: 'Home Care',
              subtitle: 'Laundry Detergent, Fragrance Boosters & Dryer Sheets',
              badgeText: 'NEW COLLECTION',
              badgeColor: gold,
              icon: Icons.local_laundry_service_outlined,
              isActive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      storeName: 'Bath & Body Works',
                      category: 'Home Care',
                      department: 'Laundry Care',
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

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFE5A93C);

    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isActive ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14171E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? gold.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1E26),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: gold.withValues(alpha: isActive ? 0.4 : 0.15)),
                ),
                child: Icon(icon, color: gold, size: 22),
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
                        if (isActive)
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
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
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
      ),
    );
  }
}
