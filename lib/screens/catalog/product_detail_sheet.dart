// File: lib/screens/catalog/product_detail_sheet.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../models/product.dart';

class ProductDetailSheet extends StatefulWidget {
  final Product product;
  final ValueChanged<Product> onAddToCart;

  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _quantity = 1;
  bool _isAdded = false;

  List<String> _getCleanNotes(List<String> rawNotes, String overview) {
    final List<String> cleaned = [];
    final lowerOverview = overview.trim().toLowerCase();

    for (final raw in rawNotes) {
      final stripped = raw
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'^(top|heart|base)\s+', caseSensitive: false), '')
          .trim();
      if (stripped.toLowerCase() == lowerOverview) continue;

      if (stripped.length > 28 && stripped.contains(' ')) {
        final parts = stripped.split(RegExp(r'\s{2,}|(?=[a-z]+ oil)'));
        for (final p in parts) {
          final cleanP = p.replaceAll(RegExp(r'^(top|heart|base)\s+', caseSensitive: false), '').trim();
          if (cleanP.isNotEmpty && cleanP.toLowerCase() != lowerOverview) {
            cleaned.add(cleanP);
          }
        }
      } else if (stripped.isNotEmpty) {
        cleaned.add(stripped);
      }
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);
    final p = widget.product;
    final String name = p.name;
    final String productType = p.productType ?? p.subCategory ?? 'Home Fragrance';
    final lowerName = name.toLowerCase();
    final lowerType = productType.toLowerCase();

    final fp = p.fragranceProfile;
    final List<String> topNotes = fp?.topNotes ?? [];
    final List<String> heartNotes = fp?.heartNotes ?? [];
    final List<String> baseNotes = fp?.baseNotes ?? [];
    final bool hasPyramid = topNotes.isNotEmpty || heartNotes.isNotEmpty || baseNotes.isNotEmpty;

    // Contextual hardware type detection
    final bool isCarAccessory = RegExp(r'\bcar\b', caseSensitive: false).hasMatch(lowerName) ||
        RegExp(r'\bcar\b', caseSensitive: false).hasMatch(lowerType);
    final bool isPlugAccessory = RegExp(r'\bplug\b', caseSensitive: false).hasMatch(lowerName) ||
        RegExp(r'\bplug\b', caseSensitive: false).hasMatch(lowerType);
    final bool isSanitizerHolder = lowerName.contains('holder') &&
        (lowerName.contains('pocketbac') || lowerName.contains('pocketspray') || lowerName.contains('sanitizer'));
    final bool isCandlePedestal = lowerName.contains('pedestal') ||
        (lowerName.contains('candle holder') && !isCarAccessory);

    final bool isHardware = isCarAccessory || isPlugAccessory || isSanitizerHolder || isCandlePedestal;
    final bool isCandle = (p.category == 'Candles' || lowerName.contains('candle')) && !isHardware;
    final bool isSingleWick = lowerName.contains('single wick') || lowerType.contains('single wick');
    final bool is4Wick = lowerName.contains('4-wick') || lowerType.contains('4-wick');

    final curPrice = (p.price ?? (p.salePrice ?? 0.0)).toDouble();
    final regPrice = (p.msrp ?? (p.regularPrice ?? curPrice)).toDouble();
    final hasRealDiscount = (regPrice - curPrice) > 0.05;
    final overview = (p.fragranceOverview ?? '').trim();
    final cleanNotes = _getCleanNotes(p.fragranceNotes, overview);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1115).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. High-Res Image Box
                      Center(
                        child: Container(
                          height: 220,
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161922),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: p.imageUrl ?? '',
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(color: gold, strokeWidth: 2),
                            ),
                            errorWidget: (_, __, ___) => const Icon(Icons.spa_outlined, color: Colors.white24, size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Brand & Subcategory / Sizing Tag
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2330),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: gold.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: Text(
                              productType.toUpperCase(),
                              style: const TextStyle(
                                color: gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          if ((p.unitShort ?? p.unit ?? '').isNotEmpty)
                            Text(
                              p.unitShort ?? p.unit!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. Product Title
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. Price & Promotion Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$${curPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: gold,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (hasRealDiscount) ...[
                            const SizedBox(width: 10),
                            Text(
                              '\$${regPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 15,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          if ((p.promoBadge ?? '').isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFEF5350), width: 0.8),
                              ),
                              child: Text(
                                p.promoBadge!.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFFF8A80),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 5. HARDWARE SPEC CARD (Contextual Specs)
                      if (isHardware) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141720),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSpecColumn(
                                icon: Icons.category_outlined,
                                label: 'TYPE',
                                val: isCarAccessory
                                    ? 'Vent Clip'
                                    : isPlugAccessory
                                        ? 'Wall Plug'
                                        : isSanitizerHolder
                                            ? 'Sanitizer Clip'
                                            : 'Pedestal',
                              ),
                              _buildSpecColumn(
                                icon: Icons.sync_alt_rounded,
                                label: 'COMPATIBILITY',
                                val: isCarAccessory
                                    ? 'Car Refills'
                                    : isPlugAccessory
                                        ? 'Wallflowers'
                                        : isSanitizerHolder
                                            ? 'PocketBac 1 oz'
                                            : '3-Wick Candles',
                              ),
                              _buildSpecColumn(
                                icon: Icons.tune_rounded,
                                label: 'FEATURE',
                                val: isCarAccessory
                                    ? 'Built-in Clip'
                                    : isPlugAccessory && lowerName.contains('nightlight')
                                        ? 'Nightlight'
                                        : isPlugAccessory
                                            ? 'Scent Control'
                                            : isSanitizerHolder
                                                ? 'Keychain Loop'
                                                : 'Protective Base',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 6. CANDLE SPEC DECK (Only for Candles)
                      if (isCandle) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141720),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSpecColumn(
                                icon: Icons.local_fire_department_outlined,
                                label: 'BURN TIME',
                                val: isSingleWick ? '30–50 Hours' : (is4Wick ? '30–50 Hours' : '25–45 Hours'),
                              ),
                              _buildSpecColumn(
                                icon: Icons.blur_on_rounded,
                                label: 'WICKS',
                                val: isSingleWick ? '1 Lead-Free' : (is4Wick ? '4 Lead-Free' : '3 Lead-Free'),
                              ),
                              _buildSpecColumn(
                                icon: Icons.home_work_outlined,
                                label: 'ROOM SIZE',
                                val: isSingleWick ? 'Medium Rooms' : 'Large Spaces',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 7. STORYTELLING & MOOD HOOK
                      if (overview.isNotEmpty && !overview.contains('Formulated with authentic')) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13161E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Text(
                            '"$overview"',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 8A. FRAGRANCE PYRAMID WIDGET (3-Stage Olfactory Profile)
                      if (!isHardware && hasPyramid) ...[
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: gold, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'OLFACTORY FRAGRANCE PYRAMID',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13161E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: gold.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (topNotes.isNotEmpty)
                                _buildPyramidTier('🌅 TOP NOTES (Opening)', topNotes),
                              if (heartNotes.isNotEmpty) ...[
                                if (topNotes.isNotEmpty) const Divider(color: Colors.white10, height: 16),
                                _buildPyramidTier('💖 HEART NOTES (Core)', heartNotes),
                              ],
                              if (baseNotes.isNotEmpty) ...[
                                if (topNotes.isNotEmpty || heartNotes.isNotEmpty) const Divider(color: Colors.white10, height: 16),
                                _buildPyramidTier('🪵 BASE NOTES (Dry Down)', baseNotes),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ]
                      // 8B. FRAGRANCE NOTE CHIPS (Clean Pills)
                      else if (!isHardware && cleanNotes.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: gold, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'FRAGRANCE PROFILE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: cleanNotes.map((note) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B202C),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: gold.withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: gold,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    note,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 9. Quantity & Add to Bag
                      Row(
                        children: [
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF161922),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                                ),
                                Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, color: gold, size: 18),
                                  onPressed: () => setState(() => _quantity++),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isAdded ? const Color(0xFF2E7D32) : gold,
                                  foregroundColor: _isAdded ? Colors.white : Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  if (_isAdded) return;
                                  HapticFeedback.heavyImpact();
                                  setState(() => _isAdded = true);

                                  cartState.addItem(
                                    CartItem(
                                      id: p.id,
                                      storeId: 'store_bbw_westover',
                                      storeName: 'Bath & Body Works',
                                      title: p.name,
                                      price: (p.price ?? p.salePrice ?? 16.95).toDouble(),
                                      subtitle: p.unitShort ?? p.unit ?? 'Standard',
                                      imageUrl: p.imageUrl ?? '',
                                      quantity: _quantity,
                                    ),
                                  );
                                  widget.onAddToCart(p);

                                  await Future.delayed(const Duration(milliseconds: 400));
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isAdded
                                      ? const Row(
                                          key: ValueKey('added'),
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'ADDED TO BAG ✓',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          'ADD TO BAG • \$${(curPrice * _quantity).toStringAsFixed(2)}',
                                          key: const ValueKey('add'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPyramidTier(String label, List<String> notes) {
    const gold = Color(0xFFE5A93C);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: gold,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: notes.map((note) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1B202C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                note,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSpecColumn({required IconData icon, required String label, required String val}) {
    const gold = Color(0xFFE5A93C);
    return Column(
      children: [
        Icon(icon, color: gold, size: 18),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
