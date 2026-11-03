// File: lib/screens/account/saved_favorites_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SavedFavoritesSheet extends StatelessWidget {
  const SavedFavoritesSheet({super.key});

  final List<Map<String, dynamic>> _favorites = const [
    {
      'name': 'After Dark 3-in-1 Hair, Face & Body Wash',
      'brand': 'Bath & Body Works',
      'price': 15.95,
      'size': '10 fl oz',
    },
    {
      'name': 'Amber Era Fine Fragrance Mist',
      'brand': 'Bath & Body Works',
      'price': 5.95,
      'size': '8 fl oz',
    },
    {
      'name': 'Crafted Cognac 3-in-1 Wash',
      'brand': 'Bath & Body Works',
      'price': 15.95,
      'size': '10 fl oz',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF14171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SAVED FAVORITE PRODUCTS',
                style: TextStyle(
                  color: Color(0xFFE5A93C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._favorites.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.spa_outlined, color: Color(0xFFE5A93C), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item['brand']} · \$${(item['price'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A93C),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${item['name']} to cart!'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                      child: const Text('ADD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
