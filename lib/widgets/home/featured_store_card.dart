// File: lib/widgets/home/featured_store_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../navigation/app_navigator.dart';

class FeaturedStoreCard extends StatelessWidget {
  final String storeName;
  final String category;
  final String deliveryEta;
  final String imageUrl;
  final double rating;
  final VoidCallback? onTap;

  const FeaturedStoreCard({
    super.key,
    required this.storeName,
    required this.category,
    required this.deliveryEta,
    required this.imageUrl,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          AppNavigator.openStoreCatalog(context, storeName: storeName);
        }
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF171A21),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Hero Cover
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: const Color(0xFF242833),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.storefront_rounded, size: 40, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: gold, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          deliveryEta,
                          style: const TextStyle(color: gold, fontSize: 10.5, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Store Metadata
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeName,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(category, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const Text(' • ', style: TextStyle(color: Colors.white24)),
                      const Icon(Icons.star_rounded, color: gold, size: 14),
                      const SizedBox(width: 2),
                      Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
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
