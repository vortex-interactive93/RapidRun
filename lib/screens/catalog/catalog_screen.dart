// File: lib/screens/catalog/catalog_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../models/product.dart';

class CatalogScreen extends StatelessWidget {
  final String storeName;
  final String category;

  const CatalogScreen({
    super.key,
    this.storeName = 'Bath & Body Works',
    this.category = 'Fragrance',
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0E),
        elevation: 0,
        title: Text(
          storeName.toUpperCase(),
          style: const TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Real-time Firestore stream: whenever Pluck updates, the UI repaints instantly!
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('store', isEqualTo: storeName)
            .where('inStock', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: gold));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('No products currently stocked in this aisle.', style: TextStyle(color: Colors.white54)),
            );
          }

          final products = docs.map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>)).toList();

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];
              return _buildProductTile(context, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductTile(BuildContext context, Product item) {
    const gold = Color(0xFFE5A93C);
    final double currentPrice = item.price ?? (item.msrp ?? 0.0);
    final double regularPrice = item.msrp ?? currentPrice;
    final bool hasSpecial = regularPrice > currentPrice && currentPrice > 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Retina CDN Image
          Expanded(
            child: Center(
              child: RapidNetworkImage(
                imageUrl: item.imageUrl ?? '',
                width: double.infinity,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Promotional Badge ($5.95 Flash Sale)
          if (hasSpecial)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'FLASH SPECIAL',
                style: TextStyle(color: Color(0xFF00E676), fontSize: 8.5, fontWeight: FontWeight.w900),
              ),
            ),

          // 3. Title & Volume
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),

          // 4. Dual Pricing Display
          Row(
            children: [
              Text(
                '\$${currentPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              if (hasSpecial) ...[
                const SizedBox(width: 6),
                Text(
                  '\$${regularPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
