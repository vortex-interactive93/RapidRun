// File: lib/screens/catalog/bbw_store_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun/screens/catalog/store_aisle_screen.dart';

class BbwStoreHubScreen extends StatelessWidget {
  const BbwStoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0E),
        elevation: 0,
        iconTheme: const IconThemeData(color: gold),
        title: const Text(
          'BATH & BODY WORKS',
          style: TextStyle(
            color: gold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Department',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse in-store physical inventory at Westover Village',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Card 1: Perfume & Cologne (58 SKUs)
            _buildDepartmentCard(
              context,
              title: 'Perfume & Cologne',
              subtitle: 'Fine Eau de Parfum, Mini Rollerballs, Luxury Colognes',
              itemCount: '58 In-Store SKUs',
              icon: Icons.auto_awesome,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      department: 'Perfume & Cologne',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Card 2: Body Sprays & Mists (100 SKUs)
            _buildDepartmentCard(
              context,
              title: 'Body Sprays & Mists',
              subtitle: 'Signature Fine Fragrance Mists, Shimmer & Deodorant Sprays',
              itemCount: '100 In-Store SKUs',
              icon: Icons.shower,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreAisleScreen(
                      department: 'Body Sprays & Mists',
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

  Widget _buildDepartmentCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String itemCount,
    required IconData icon,
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gold.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: gold, size: 26),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 13),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    itemCount,
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
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
