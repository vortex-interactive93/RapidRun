// File: lib/screens/catalog/widgets/product_detail_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProductDetailSheet extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailSheet({
    super.key,
    required this.product,
  });

  static void show(BuildContext context, Map<String, dynamic> product) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(product: product),
    );
  }

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final item = widget.product;
    final theme = Theme.of(context);

    final String name = (item['name'] ?? 'Product').toString().trim();
    final String productType = (item['productType'] ?? item['subCategory'] ?? 'Home Fragrance').toString().trim();
    final String unit = (item['unit'] ?? item['unitShort'] ?? '').toString().trim();
    final double price = (item['price'] ?? item['salePrice'] ?? 0.0).toDouble();
    final double regularPrice = (item['regularPrice'] ?? price).toDouble();
    final bool hasMarkdown = (regularPrice - price) > 0.05;
    final String promoBadge = (item['promoBadge'] ?? '').toString().trim();
    final String imageUrl = (item['imageUrl'] ?? '').toString().trim();
    final String overview = (item['fragranceOverview'] ?? '').toString().trim();
    final List<dynamic> notesRaw = item['fragranceNotes'] ?? [];
    final List<String> notes = notesRaw.map((e) => e.toString()).toList();

    final Map<String, dynamic>? fp = item['fragranceProfile'] is Map
        ? Map<String, dynamic>.from(item['fragranceProfile'] as Map)
        : null;

    final List<String> topNotes = (fp?['topNotes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final List<String> heartNotes = (fp?['heartNotes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final List<String> baseNotes = (fp?['baseNotes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final bool hasPyramid = topNotes.isNotEmpty || heartNotes.isNotEmpty || baseNotes.isNotEmpty;

    // Contextual hardware type detection (using word boundaries to prevent 'body care' matching 'car')
    final String lowerName = name.toLowerCase();
    final String lowerType = productType.toLowerCase();

    final bool isCarAccessory = RegExp(r'\bcar\b', caseSensitive: false).hasMatch(lowerName) ||
        RegExp(r'\bcar\b', caseSensitive: false).hasMatch(lowerType);
    final bool isPlugAccessory = RegExp(r'\bplug\b', caseSensitive: false).hasMatch(lowerName) ||
        RegExp(r'\bplug\b', caseSensitive: false).hasMatch(lowerType);
    final bool isSanitizerHolder = lowerName.contains('holder') &&
        (lowerName.contains('pocketbac') || lowerName.contains('pocketspray') || lowerName.contains('sanitizer'));
    final bool isCandlePedestal = lowerName.contains('pedestal') ||
        (lowerName.contains('candle holder') && !isCarAccessory);

    final bool isHardware = isCarAccessory || isPlugAccessory || isSanitizerHolder || isCandlePedestal;
    final bool isCandle = lowerName.contains('candle') && !isHardware;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1115),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0x33E5A93C), width: 1.2),
        ),
      ),
      child: Column(
        children: [
          // Drag Indicator
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO PRODUCT IMAGE
                  Center(
                    child: Container(
                      height: 240,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161922),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Color(0xFFE5A93C)),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.spa_outlined, color: Colors.white24, size: 48),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.spa_outlined, color: Colors.white24, size: 48),
                              ),
                      ),
                    ),
                  ),

                  // 2. PRODUCT DESCRIPTOR BADGE & VOLUME
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2330),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          productType.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFE5A93C),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (unit.isNotEmpty)
                        Text(
                          unit,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3. PRODUCT TITLE
                  Text(
                    name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. PRICING & PROMOTIONAL TAGS
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (hasMarkdown) ...[
                        const SizedBox(width: 10),
                        Text(
                          '\$${regularPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 15,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      if (promoBadge.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEF5350), width: 0.8),
                          ),
                          child: Text(
                            promoBadge.toUpperCase(),
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
                  const SizedBox(height: 20),

                  // 5. HARDWARE SPEC CARD
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

                  // 6. CANDLE SPEC CARD
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
                            val: productType.contains('3-Wick') ? '25–45 Hours' : '30–50 Hours',
                          ),
                          _buildSpecColumn(
                            icon: Icons.blur_on_rounded,
                            label: 'WICKS',
                            val: productType.contains('3-Wick') ? '3 Lead-Free' : '1 Lead-Free',
                          ),
                          _buildSpecColumn(
                            icon: Icons.home_work_outlined,
                            label: 'ROOM SIZE',
                            val: productType.contains('3-Wick') ? 'Large Spaces' : 'Medium Rooms',
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
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 8A. FRAGRANCE PYRAMID WIDGET (3-Stage Olfactory Profile)
                  if (!isHardware && hasPyramid) ...[
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFFE5A93C), size: 16),
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
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.25),
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
                    const SizedBox(height: 24),
                  ]
                  // 8B. STANDARD FRAGRANCE NOTE CHIPS (Clean Pills)
                  else if (!isHardware && notes.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFFE5A93C), size: 16),
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
                      children: notes.map((note) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B202C),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE5A93C).withValues(alpha: 0.25),
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
                                  color: Color(0xFFE5A93C),
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
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),

          // 9. STICKY ACTION DECK
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF12141A),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                // Stepper
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1E27),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                        onPressed: _quantity > 1
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _quantity--);
                              }
                            : null,
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _quantity++);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Primary CTA
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A93C),
                      foregroundColor: const Color(0xFF0F1115),
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'ADD TO BAG • \$${(price * _quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
