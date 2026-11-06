// File: lib/screens/catalog/store_aisle_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../models/product.dart';
import '../../services/favorites_cart_service.dart';
import '../../services/data_seeder_service.dart';
import '../../utils/catalog_filter_engine.dart';
import '../../widgets/navigation/app_bar_cart_badge.dart';
import 'widgets/catalog_filter_bar.dart';
import 'product_detail_sheet.dart';

class StoreAisleScreen extends StatefulWidget {
  final String storeName;
  final String category;
  final String department;
  final String subCategory;
  final String initialCategory;
  final ValueChanged<Product>? onAddToCart;

  const StoreAisleScreen({
    super.key,
    this.storeName = 'Bath & Body Works',
    this.category = 'Fragrance',
    this.department = 'All Fragrances',
    this.subCategory = '',
    this.initialCategory = 'All',
    this.onAddToCart,
  });

  @override
  State<StoreAisleScreen> createState() => _StoreAisleScreenState();
}

class _StoreAisleScreenState extends State<StoreAisleScreen> {
  late String _selectedFilter;
  late List<String> _availableChips;
  String _searchQuery = '';
  SortOption _sortOption = SortOption.featured;
  final TextEditingController _searchController = TextEditingController();

  String get activeAisleDepartment {
    if (widget.department.isNotEmpty) return widget.department;
    if (widget.subCategory.isNotEmpty) return widget.subCategory;
    return 'All Fragrances';
  }

  @override
  void initState() {
    super.initState();
    _availableChips = CatalogFilterEngine.getFilterChipsForDepartment(activeAisleDepartment);
    if (_availableChips.contains(widget.initialCategory)) {
      _selectedFilter = widget.initialCategory;
    } else {
      _selectedFilter = 'All';
    }
    // Auto-seed all Bath & Body Works catalogs into Cloud Firestore
    DataSeederService.seedAllCatalogs();
  }

  @override
  void didUpdateWidget(covariant StoreAisleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.department != widget.department ||
        oldWidget.category != widget.category ||
        oldWidget.subCategory != widget.subCategory) {
      setState(() {
        _availableChips = CatalogFilterEngine.getFilterChipsForDepartment(activeAisleDepartment);
        _selectedFilter = 'All';
      });
    }
  }

  bool _matchesDepartment(String dept, Product p, String pType) {
    final lowerDept = dept.toLowerCase();

    // 1. Broad Department All-Match Rules
    if (lowerDept == 'all' ||
        lowerDept == 'all body care' ||
        lowerDept == 'all fragrances' ||
        lowerDept == 'fragrance' ||
        lowerDept == 'all candles' ||
        lowerDept == 'all hand soaps' ||
        lowerDept == 'all hand sanitizers' ||
        lowerDept == 'wallflowers' ||
        lowerDept == "the men's shop" ||
        lowerDept == 'laundry care' ||
        lowerDept == 'all products') {
      return true;
    }

    final lowerName = p.name.toLowerCase();
    final lowerType = pType.toLowerCase();
    final lowerSub = (p.subCategory ?? '').toLowerCase();

    // 2. Specific Subcategory Matching
    if (lowerDept.contains('moisturizer')) {
      return lowerName.contains('lotion') ||
          lowerName.contains('cream') ||
          lowerName.contains('butter') ||
          lowerName.contains('balm') ||
          lowerName.contains('oil') ||
          lowerType.contains('lotion') ||
          lowerType.contains('cream') ||
          lowerType.contains('moisturizer');
    }

    if (lowerDept.contains('bath') || lowerDept.contains('shower')) {
      return lowerName.contains('wash') ||
          lowerName.contains('gel') ||
          lowerName.contains('shower') ||
          lowerName.contains('scrub') ||
          lowerName.contains('bar') ||
          lowerType.contains('wash') ||
          lowerType.contains('shower') ||
          lowerType.contains('scrub');
    }

    if (lowerDept.contains('mini') || lowerDept.contains('travel')) {
      final unit = (p.unitShort ?? p.unit ?? '').toLowerCase();
      return lowerName.contains('travel') ||
          lowerName.contains('mini') ||
          lowerName.contains('rollerball') ||
          unit.contains('1 oz') ||
          unit.contains('2.5 oz') ||
          unit.contains('0.25 oz') ||
          unit.contains('3 oz');
    }

    if (lowerDept.contains('lip')) {
      return lowerName.contains('lip') || lowerType.contains('lip') || lowerSub.contains('lip');
    }

    if (lowerDept.contains('mist') || lowerDept.contains('spray')) {
      return lowerName.contains('mist') || lowerName.contains('spray') || lowerType.contains('mist') || lowerType.contains('spray');
    }

    if (lowerDept.contains('perfume') || lowerDept.contains('cologne')) {
      return lowerName.contains('perfume') ||
          lowerName.contains('cologne') ||
          lowerName.contains('parfum') ||
          lowerType.contains('perfume') ||
          lowerType.contains('cologne');
    }

    return lowerName.contains(lowerDept) || lowerType.contains(lowerDept) || lowerSub.contains(lowerDept);
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);

    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('store', isEqualTo: widget.storeName)
        .where('inStock', isEqualTo: true);

    if (widget.category == 'Home Care' || widget.category == 'Laundry Care') {
      query = query.where('category', isEqualTo: 'Home Care');
    } else if (widget.category == "The Men's Shop") {
      query = query.where('category', isEqualTo: "The Men's Shop");
    } else if (widget.category == 'Hand Soaps & Sanitizers') {
      query = query.where('category', isEqualTo: 'Hand Soaps & Sanitizers');
    } else if (widget.category == 'Wallflowers & Diffusers') {
      query = query.where('category', isEqualTo: 'Wallflowers & Diffusers');
    } else if (widget.category == 'Candles') {
      query = query.where('category', isEqualTo: 'Candles');
    } else if (widget.category == 'Fragrance' || activeAisleDepartment == 'All Fragrances' || activeAisleDepartment == 'Perfume & Cologne' || activeAisleDepartment == 'Body Sprays & Mists') {
      query = query.where('category', isEqualTo: 'Fragrance');
    } else {
      query = query.where('category', isEqualTo: 'Body Care');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0E),
        elevation: 0,
        iconTheme: const IconThemeData(color: gold),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.storeName.toUpperCase(),
              style: const TextStyle(
                color: gold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              activeAisleDepartment,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          const AppBarCartBadge(),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort, color: gold, size: 20),
            color: const Color(0xFF161922),
            onSelected: (opt) => setState(() => _sortOption = opt),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: SortOption.featured,
                child: Text('Featured Curation', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const PopupMenuItem(
                value: SortOption.priceLowToHigh,
                child: Text('Price: Low to High', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const PopupMenuItem(
                value: SortOption.priceHighToLow,
                child: Text('Price: High to Low', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const PopupMenuItem(
                value: SortOption.onSaleOnly,
                child: Text('Promotions & Deals Only', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Search $activeAisleDepartment...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: gold, size: 19),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF14171E),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: gold, width: 1.2),
                ),
              ),
            ),
          ),

          // 2. Animated Predicate Filter Chips
          CatalogFilterBar(
            chips: _availableChips,
            selectedChip: _selectedFilter,
            onChipSelected: (newChip) {
              setState(() => _selectedFilter = newChip);
            },
          ),

          // 3. Firestore Product Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: gold, strokeWidth: 2));
                }

                final rawProducts = snapshot.data!.docs
                    .map((d) => Product.fromJson(d.data() as Map<String, dynamic>))
                    .toList();

                if (rawProducts.isEmpty) {
                  return const Center(
                    child: Text('No matching in-store items found.', style: TextStyle(color: Colors.white54)),
                  );
                }

                // Apply Department, Predicate Subcategory Filter, Search Query & Sort
                List<Product> filtered = rawProducts.where((p) {
                  final rawJson = snapshot.data!.docs
                      .firstWhere((d) => d.id == p.id)
                      .data() as Map<String, dynamic>;
                  final pType = (rawJson['productType'] ?? p.subCategory ?? '').toString();

                  final matchesDept = _matchesDepartment(activeAisleDepartment, p, pType);
                  final matchesPill = CatalogFilterEngine.matchesSubcategoryPredicate(p, _selectedFilter);
                  final matchesSearch = _searchQuery.isEmpty ||
                      p.name.toLowerCase().contains(_searchQuery) ||
                      p.fragranceNotes.any((n) => n.toLowerCase().contains(_searchQuery));

                  return matchesDept && matchesPill && matchesSearch;
                }).toList();

                // Sort Options Engine
                switch (_sortOption) {
                  case SortOption.priceLowToHigh:
                    filtered.sort((a, b) => (a.price ?? 0.0).compareTo(b.price ?? 0.0));
                    break;
                  case SortOption.priceHighToLow:
                    filtered.sort((a, b) => (b.price ?? 0.0).compareTo(a.price ?? 0.0));
                    break;
                  case SortOption.onSaleOnly:
                    filtered = filtered.where((p) => p.hasSpecial || (p.promoBadge ?? '').isNotEmpty).toList();
                    break;
                  case SortOption.featured:
                  default:
                    break;
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No matching in-store items found.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    final rawJson = snapshot.data!.docs
                        .firstWhere((d) => d.id == p.id)
                        .data() as Map<String, dynamic>;
                    final pType = (rawJson['productType'] ?? p.subCategory ?? '').toString();
                    return _buildProductCard(context, p, pType);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product p, String displayType) {
    const gold = Color(0xFFE5A93C);
    final double curPrice = (p.price ?? (p.salePrice ?? 0.0)).toDouble();
    double regPrice = (p.msrp ?? (p.regularPrice ?? curPrice)).toDouble();

    final String rawBadge = (p.promoBadge ?? '').trim();
    final bool isMixAndMatch = rawBadge.toLowerCase().contains('buy 3') || rawBadge.toLowerCase().contains('mix & match');
    final bool isFakeEvent = rawBadge.contains('In-Store Event') || rawBadge.contains('Event');
    final bool isLipOrHand = displayType == 'Lip Care' || displayType == 'Hand Cream';

    if (isLipOrHand) {
      regPrice = curPrice;
    }

    final bool hasRealDiscount = (regPrice - curPrice) > 0.05 && !isFakeEvent && !isLipOrHand;
    final bool shouldShowBadge = (isMixAndMatch || hasRealDiscount) && !isFakeEvent;
    final int savePercent = (hasRealDiscount && regPrice > 0) ? (((regPrice - curPrice) / regPrice) * 100).round() : 0;
    final unitLabel = p.unitShort ?? (p.unit ?? '8 oz');

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ProductDetailSheet(
            product: p,
            onAddToCart: (Product item) {
              if (widget.onAddToCart != null) widget.onAddToCart!(item);
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14171E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HERO: Pedestal Photo Box
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RapidNetworkImage(
                    imageUrl: p.imageUrl ?? '',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 2. METADATA ROW: Product Type & Size/Weight
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayType.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: gold.withValues(alpha: 0.85),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unitLabel,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),

            // 3. PRODUCT TITLE
            Text(
              p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),

            // 4. UNIFIED DEAL SLOT
            if (shouldShowBadge)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isMixAndMatch
                      ? const Color(0xFFFF5252).withValues(alpha: 0.14)
                      : gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isMixAndMatch
                        ? const Color(0xFFFF5252).withValues(alpha: 0.35)
                        : gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  isMixAndMatch
                      ? (rawBadge.isNotEmpty ? rawBadge.toUpperCase() : 'MIX & MATCH: BUY 3, GET 1 FREE')
                      : (savePercent > 0 ? 'CLEARANCE • $savePercent% OFF' : 'CLEARANCE'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMixAndMatch ? const Color(0xFFFF6E6E) : gold,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

            const SizedBox(height: 4),

            // 5. PRICE & QUICK ADD BUTTON
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${curPrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: gold, fontSize: 14.5, fontWeight: FontWeight.w900),
                    ),
                    if (hasRealDiscount)
                      Text(
                        '\$${regPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.5,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                ListenableBuilder(
                  listenable: cartState,
                  builder: (context, _) {
                    final qty = cartState.quantityFor(p.id);

                    if (qty == 0) {
                      return GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await CartService.instance.addProduct(p, 1);
                          if (widget.onAddToCart != null) widget.onAddToCart!(p);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                              CartService.instance.setQuantity(p.id, qty - 1);
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
                              await CartService.instance.addProduct(p, 1);
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
