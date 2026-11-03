// File: lib/screens/store/unified_store_catalog_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../models/product.dart';
import '../../services/bbw_catalog_service.dart';
import '../../services/product_catalog_service.dart';
import '../product_detail_screen.dart';
import '../shopping/cart_screen.dart';
import '../../widgets/catalog/luxury_product_card.dart';

class UnifiedStoreCatalogScreen extends StatefulWidget {
  final String storeName;

  const UnifiedStoreCatalogScreen({
    super.key,
    this.storeName = 'Bath & Body Works',
  });

  @override
  State<UnifiedStoreCatalogScreen> createState() => _UnifiedStoreCatalogScreenState();
}

class _UnifiedStoreCatalogScreenState extends State<UnifiedStoreCatalogScreen> {
  int _selectedCategoryIndex = 0;
  int _selectedSubCategoryIndex = 0;
  bool _isLoading = true;
  List<Product> _allStoreProducts = [];

  bool get _isAldi => widget.storeName.toLowerCase().contains('aldi');

  List<String> get _categories => _isAldi
      ? ['Produce', 'Dairy & Eggs', 'Bakery', 'Pantry', 'Meat & Seafood']
      : ['Fragrance', 'Body Care', 'Candles', 'Wallflowers', 'Hand Soaps', 'Men\'s Shop'];

  Map<String, List<String>> get _subCategories => _isAldi
      ? {
          'Produce': ['All', 'Fresh Fruits', 'Fresh Vegetables', 'Salads'],
          'Dairy & Eggs': ['All', 'Milk & Cream', 'Cheese', 'Eggs', 'Butter'],
          'Bakery': ['All', 'Bread', 'Buns & Rolls', 'Pastries'],
          'Pantry': ['All', 'Canned Goods', 'Pasta & Grains', 'Spices'],
          'Meat & Seafood': ['All', 'Beef', 'Poultry', 'Seafood'],
        }
      : {
          'Fragrance': ['All', 'Perfume & Cologne', 'Body Mists', 'Body Sprays'],
          'Body Care': ['All', 'Moisturizers', 'Bath & Shower', 'Travel Size', 'Lip Care'],
          'Candles': ['All', '3-Wick Candles', 'Single-Wick', 'Holders'],
          'Wallflowers': ['All', 'Plugs', 'Refills', 'Mists & Sprays'],
          'Hand Soaps': ['All', 'Foaming', 'Gel Soaps', 'PocketBac'],
          'Men\'s Shop': ['All', '3-in-1 Wash', 'Cologne', 'Body Spray'],
        };

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    try {
      List<Product> products = [];
      if (_isAldi) {
        await ProductCatalogService.instance.ensureLoaded();
        final all = ProductCatalogService.instance.all().toList();
        products = all.where((p) => (p.store ?? '').toLowerCase().contains('aldi')).toList();
        if (products.isEmpty) {
          products = all.take(40).toList();
        }
      } else {
        products = await BBWCatalogService.instance.getEnrichedCatalog();
      }

      if (mounted) {
        setState(() {
          _allStoreProducts = products;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Product> _filterProducts() {
    if (_allStoreProducts.isEmpty) return [];
    final activeCat = _categories[_selectedCategoryIndex].toLowerCase();
    final activeSubCats = _subCategories[_categories[_selectedCategoryIndex]] ?? ['All'];
    final activeSub = activeSubCats[_selectedSubCategoryIndex].toLowerCase();

    return _allStoreProducts.where((p) {
      final pCat = (p.category ?? '').toLowerCase();
      final pSub = (p.subCategory ?? '').toLowerCase();
      final pName = p.name.toLowerCase();

      final matchesCategory = pCat.contains(activeCat) || pSub.contains(activeCat) || pName.contains(activeCat);

      if (activeSub == 'all') return matchesCategory || _allStoreProducts.length < 20;

      final matchesSub = pSub.contains(activeSub) || pName.contains(activeSub);
      return (matchesCategory || _allStoreProducts.length < 20) && matchesSub;
    }).toList();
  }

  void _openProductDetail(Product product) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          id: product.id,
          name: product.name,
          brand: product.brand,
          imageUrl: product.imageUrl,
          description: product.description ?? '',
          price: product.price,
          unit: product.unit,
          unitShort: product.unitShort,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSubCats = _subCategories[_categories[_selectedCategoryIndex]] ?? ['All'];
    final filtered = _filterProducts();
    final displayedProducts = filtered.isNotEmpty ? filtered : _allStoreProducts;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Frosted Store App Bar with Cart Counter & Exit
              SliverAppBar(
                backgroundColor: const Color(0xFF14171D).withValues(alpha: 0.9),
                pinned: true,
                expandedHeight: 140,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  ListenableBuilder(
                    listenable: cartState,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFE5A93C), size: 24),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                            },
                          ),
                          if (cartState.totalItemCount > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Color(0xFFE5A93C), shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  '${cartState.totalItemCount}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Exit to Home',
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.storeName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          Icon(Icons.bolt, color: Color(0xFFE5A93C), size: 12),
                          SizedBox(width: 3),
                          Text(
                            '20–30 min delivery',
                            style: TextStyle(color: Color(0xFFE5A93C), fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Primary Category Tabs
              SliverToBoxAdapter(
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(top: 12),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isSelected = _selectedCategoryIndex == index;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategoryIndex = index;
                            _selectedSubCategoryIndex = 0;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF181B22),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isSelected ? const Color(0xFFE5A93C) : Colors.white10),
                          ),
                          child: Text(
                            _categories[index],
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 3. Sub-Category Rail
              SliverToBoxAdapter(
                child: Container(
                  height: 38,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: activeSubCats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final isSelected = _selectedSubCategoryIndex == index;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedSubCategoryIndex = index);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? const Color(0xFFE5A93C) : Colors.white12),
                          ),
                          child: Text(
                            activeSubCats[index],
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFE5A93C) : Colors.white54,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 4. Product Grid
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFFE5A93C))),
                )
              else if (displayedProducts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No products found in this aisle', style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = displayedProducts[index];
                        return LuxuryProductCard(
                          id: product.id,
                          title: product.name,
                          brand: product.brand ?? widget.storeName,
                          size: product.unitShort ?? product.unit ?? 'Regular',
                          price: product.price ?? 9.99,
                          imageUrl: product.imageUrl ?? '',
                          onTap: () => _openProductDetail(product),
                        );
                      },
                      childCount: displayedProducts.length,
                    ),
                  ),
                ),
            ],
          ),

          // 5. Floating Frosted Mini-Cart HUD
          Positioned(
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: _FrostedMiniCartHud(
              onViewCartPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedMiniCartHud extends StatelessWidget {
  final VoidCallback onViewCartPressed;
  const _FrostedMiniCartHud({required this.onViewCartPressed});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartState,
      builder: (context, _) {
        if (cartState.isEmpty) return const SizedBox.shrink();

        return RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14171D).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFE5A93C), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${cartState.totalItemCount}',
                        style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ESTIMATED TOTAL', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w800)),
                        Text(
                          '\$${cartState.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A93C),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: onViewCartPressed,
                      child: const Row(
                        children: [
                          Text('View Cart', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.black),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
