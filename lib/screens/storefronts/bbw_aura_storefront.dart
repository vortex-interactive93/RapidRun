// File: lib/screens/storefronts/bbw_aura_storefront.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../services/favorites_cart_service.dart';
import '../catalog/product_detail_sheet.dart';
import '../../widgets/navigation/app_bar_cart_badge.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

class BBWAuraStorefront extends StatefulWidget {
  final List<Product> allProducts;

  const BBWAuraStorefront({super.key, required this.allProducts});

  @override
  State<BBWAuraStorefront> createState() => _BBWAuraStorefrontState();
}

class _BBWAuraStorefrontState extends State<BBWAuraStorefront> {
  String _selectedAura = 'All Vibes';

  final Map<String, List<String>> _auraMap = {
    'All Vibes': [],
    'Warm & Cozy': ['vanilla', 'cashmere', 'caramel', 'amber', 'tonka', 'cinnamon', 'sugar'],
    'Fresh Woods': ['mahogany', 'teakwood', 'pine', 'eucalyptus', 'balsam', 'cedar', 'cypress'],
    'Fruity Sparkle': ['prosecco', 'raspberry', 'tangerine', 'apple', 'peach', 'strawberry', 'citrus'],
    'Floral Escape': ['jasmine', 'rose', 'lavender', 'orchid', 'freesia', 'blossom', 'petal'],
  };

  List<Product> get filteredProducts {
    if (_selectedAura == 'All Vibes') return widget.allProducts;

    final targetNotes = _auraMap[_selectedAura]!;
    return widget.allProducts.where((product) {
      final notesStr = product.fragranceNotes.join(' ').toLowerCase();
      final nameStr = product.name.toLowerCase();
      final overviewStr = (product.fragranceOverview ?? '').toLowerCase();
      final combined = '$notesStr $nameStr $overviewStr';
      return targetNotes.any((note) => combined.contains(note));
    }).toList();
  }

  Color get _activeAuraColor {
    switch (_selectedAura) {
      case 'Warm & Cozy':
        return const Color(0xFFE5A93C);
      case 'Fresh Woods':
        return const Color(0xFF10B981);
      case 'Fruity Sparkle':
        return const Color(0xFFF43F5E);
      case 'Floral Escape':
        return const Color(0xFFA855F7);
      case 'All Vibes':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildFrostedAppBar(),
          _buildAuraSelector(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: products.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No matching scents found for $_selectedAura.',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.58,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _AuraProductCard(product: products[index]);
                      },
                      childCount: products.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrostedAppBar() {
    const gold = Color(0xFFE5A93C);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: gold),
      actions: const [
        AppBarCartBadge(),
      ],
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
            title: Text(
              'Scent Aura: $_selectedAura',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            background: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _activeAuraColor.withValues(alpha: 0.25),
                    const Color(0xFF0F1115),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuraSelector() {
    return SliverToBoxAdapter(
      child: Container(
        height: 52,
        margin: const EdgeInsets.only(top: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _auraMap.keys.length,
          itemBuilder: (context, index) {
            final aura = _auraMap.keys.elementAt(index);
            final isSelected = _selectedAura == aura;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedAura = aura);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.fastOutSlowIn,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _activeAuraColor : const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? _activeAuraColor : Colors.white.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _activeAuraColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    aura,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 12.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuraProductCard extends StatelessWidget {
  final Product product;

  const _AuraProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);
    final curPrice = (product.price ?? (product.salePrice ?? 16.95)).toDouble();
    final regPrice = (product.msrp ?? (product.regularPrice ?? curPrice)).toDouble();
    final hasRealDiscount = (regPrice - curPrice) > 0.05;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ProductDetailSheet(
            product: product,
            onAddToCart: (Product item) async {
              await CartService.instance.addProduct(item, 1);
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14171E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Box
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF191D28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.spa_outlined, color: Colors.white24, size: 36),
                      )
                    : const Icon(Icons.spa_outlined, color: Colors.white24, size: 36),
              ),
            ),
            const SizedBox(height: 6),

            // Category/Brand Tag
            Text(
              (product.productType ?? product.subCategory ?? 'Bath & Body Works').toUpperCase(),
              style: const TextStyle(
                color: gold,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // Name
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),

            // Price & Morphing Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${curPrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    if (hasRealDiscount)
                      Text(
                        '\$${regPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.5,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),

                ListenableBuilder(
                  listenable: cartState,
                  builder: (context, _) {
                    final qty = cartState.quantityFor(product.id);

                    if (qty == 0) {
                      return GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await CartService.instance.addProduct(product, 1);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: gold,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.black, size: 16),
                        ),
                      );
                    }

                    return Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161922),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: gold.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              CartService.instance.setQuantity(product.id, qty - 1);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.remove, color: Colors.white70, size: 14),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '$qty',
                              style: const TextStyle(
                                color: gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await CartService.instance.addProduct(product, 1);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.add, color: gold, size: 14),
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
    );
  }
}
