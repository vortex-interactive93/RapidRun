// File: lib/widgets/catalog/luxury_product_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

class LuxuryProductCard extends StatelessWidget {
  final String? id;
  final String title;
  final String brand;
  final String size;
  final double price;
  final String imageUrl;
  final VoidCallback? onAddToCart;
  final VoidCallback? onTap;

  const LuxuryProductCard({
    super.key,
    this.id,
    required this.title,
    required this.brand,
    required this.size,
    required this.price,
    required this.imageUrl,
    this.onAddToCart,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemId = id ?? title.replaceAll(' ', '_').toLowerCase();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14171D), // Obsidian Base
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Showcase with Ambient Dark Backdrop & RapidNetworkImage
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E26), // Charcoal Canvas
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFE5A93C).withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            radius: 0.6,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: RapidNetworkImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 12,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Metadata & Stepper Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    size,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      // Reactive Inline Stepper
                      ListenableBuilder(
                        listenable: cartState,
                        builder: (context, _) {
                          CartItem? currentItem;
                          for (final i in cartState.items) {
                            if (i.id == itemId) {
                              currentItem = i;
                              break;
                            }
                          }
                          final qty = currentItem?.quantity ?? 0;

                          if (qty == 0) {
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                if (onAddToCart != null) {
                                  onAddToCart!();
                                } else {
                                  cartState.addItem(
                                    CartItem(
                                      id: itemId,
                                      title: title,
                                      storeName: brand,
                                      price: price,
                                      subtitle: size,
                                      imageUrl: imageUrl,
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5A93C),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add, color: Colors.black, size: 18),
                              ),
                            );
                          }

                          return Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222630),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5A93C), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    cartState.updateQuantity(itemId, qty - 1);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(Icons.remove, color: Color(0xFFE5A93C), size: 16),
                                  ),
                                ),
                                Text(
                                  '$qty',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    cartState.updateQuantity(itemId, qty + 1);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(Icons.add, color: Color(0xFFE5A93C), size: 16),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
