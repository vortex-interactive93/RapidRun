// File: lib/screens/catalog/bbw_store_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../services/favorites_cart_service.dart';
import 'product_detail_sheet.dart';
import '../../widgets/navigation/app_bar_cart_badge.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

/// Represents a hermetically sealed Boutique Room backed directly by a specific JSON asset.
class BbwBoutiqueRoom {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> candidateAssetPaths;
  final List<Color> gradientColors;

  const BbwBoutiqueRoom({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.candidateAssetPaths,
    required this.gradientColors,
  });
}

class BbwStoreScreen extends StatefulWidget {
  final String? initialRoomId;

  const BbwStoreScreen({
    super.key,
    this.initialRoomId,
  });

  @override
  State<BbwStoreScreen> createState() => _BbwStoreScreenState();
}

class _BbwStoreScreenState extends State<BbwStoreScreen> {
  // 1:1 Direct Mapping to JSON files. No mixing, zero cross-contamination!
  static const List<BbwBoutiqueRoom> _boutiques = [
    BbwBoutiqueRoom(
      id: 'candles',
      title: 'The Candle Vault',
      subtitle: '3-Wick & Single Wick',
      icon: Icons.local_fire_department_rounded,
      candidateAssetPaths: [
        'assets/data/all_candles.json',
        'assets/data/candles.json',
        'assets/data/3_wick_candles.json',
      ],
      gradientColors: [Color(0xFFD97706), Color(0xFF78350F)],
    ),
    BbwBoutiqueRoom(
      id: 'body_care',
      title: 'Body & Shower',
      subtitle: 'Lotions, Washes & Scrubs',
      icon: Icons.spa_rounded,
      candidateAssetPaths: [
        'assets/data/body_care.json',
        'assets/data/all_moisturizers.json',
        'assets/data/bath_shower.json',
      ],
      gradientColors: [Color(0xFFEC4899), Color(0xFF831843)],
    ),
    BbwBoutiqueRoom(
      id: 'fragrance',
      title: 'Fine Fragrance',
      subtitle: 'Mists, Perfumes & Spritz',
      icon: Icons.auto_awesome_rounded,
      candidateAssetPaths: [
        'assets/data/all_fragrance.json',
        'assets/data/Body_Sprays_Mists.json',
        'assets/data/Perfume_Cologne.json',
      ],
      gradientColors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
    ),
    BbwBoutiqueRoom(
      id: 'soaps',
      title: 'Soaps & PocketBacs',
      subtitle: 'Foaming, Gel & Sanitizers',
      icon: Icons.clean_hands_rounded,
      candidateAssetPaths: [
        'assets/data/hand_soaps_sanitizers.json',
        'assets/data/all_hand_soaps.json',
        'assets/data/all_hand_sanitizers.json',
      ],
      gradientColors: [Color(0xFF06B6D4), Color(0xFF164E63)],
    ),
    BbwBoutiqueRoom(
      id: 'wallflowers',
      title: 'Wallflowers & Air',
      subtitle: 'Plugs, Refills & Room Sprays',
      icon: Icons.air_rounded,
      candidateAssetPaths: [
        'assets/data/wallflowers_diffusers.json',
        'assets/data/all_wallflowers.json',
        'assets/data/room_sprays_mists.json',
      ],
      gradientColors: [Color(0xFF10B981), Color(0xFF064E3B)],
    ),
    BbwBoutiqueRoom(
      id: 'mens',
      title: "Men's Reserve",
      subtitle: 'Cologne, 3-in-1 & Grooming',
      icon: Icons.shield_moon_rounded,
      candidateAssetPaths: [
        'assets/data/mens_shop.json',
      ],
      gradientColors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
    ),
    BbwBoutiqueRoom(
      id: 'home_care',
      title: 'Home & Laundry',
      subtitle: 'Detergent & Scent Boosters',
      icon: Icons.local_laundry_service_rounded,
      candidateAssetPaths: [
        'assets/data/home_care.json',
        'assets/data/laundry_care.json',
      ],
      gradientColors: [Color(0xFFF59E0B), Color(0xFF92400E)],
    ),
  ];

  // Quick Scent Note Spotlights
  static const List<String> _scentSpotlights = [
    'All Scents',
    'Vanilla',
    'Mahogany',
    'Lavender',
    'Champagne',
    'Peppermint',
    'Apple',
    'Eucalyptus',
    'Coconut',
  ];

  int _selectedBoutiqueIndex = 0;
  String _selectedScentNote = 'All Scents';
  bool _onlyPromoDeals = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // In-memory cache of each boutique's isolated product list
  final Map<String, List<Product>> _roomProductsCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoomId != null) {
      final idx = _boutiques.indexWhere((b) => b.id == widget.initialRoomId);
      if (idx >= 0) _selectedBoutiqueIndex = idx;
    }
    _loadActiveBoutique();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads the exact JSON file for the selected Boutique Room.
  /// Zero cross-category mixing.
  Future<void> _loadActiveBoutique() async {
    final room = _boutiques[_selectedBoutiqueIndex];
    if (_roomProductsCache.containsKey(room.id) && _roomProductsCache[room.id]!.isNotEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    List<Product> loaded = [];
    for (final path in room.candidateAssetPaths) {
      try {
        final rawJson = await rootBundle.loadString(path);
        final List<dynamic> decoded = json.decode(rawJson);
        final seenIds = <String>{};

        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final product = Product.fromJson(item);
            if (product.id.isNotEmpty && seenIds.add(product.id)) {
              loaded.add(product);
            }
          }
        }
        if (loaded.isNotEmpty) break;
      } catch (e) {
        debugPrint('⚠️ [Boutique] Note: Asset path $path skipped: $e');
      }
    }

    if (mounted) {
      setState(() {
        _roomProductsCache[room.id] = loaded;
        _isLoading = false;
      });
    }
  }

  List<Product> get _filteredProducts {
    final room = _boutiques[_selectedBoutiqueIndex];
    final rawList = _roomProductsCache[room.id] ?? [];

    return rawList.where((product) {
      // 1. Live Search bar check (Name + Fragrance Overview + Notes)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = product.name.toLowerCase().contains(q);
        final matchOverview = (product.fragranceOverview ?? '').toLowerCase().contains(q);
        final matchNotes = product.fragranceNotes.any((n) => n.toLowerCase().contains(q));
        if (!matchName && !matchOverview && !matchNotes) return false;
      }

      // 2. Scent Note Spotlight check
      if (_selectedScentNote != 'All Scents') {
        final noteQuery = _selectedScentNote.toLowerCase();
        final inName = product.name.toLowerCase().contains(noteQuery);
        final inNotes = product.fragranceNotes.any((n) => n.toLowerCase().contains(noteQuery));
        final inOverview = (product.fragranceOverview ?? '').toLowerCase().contains(noteQuery);
        if (!inName && !inNotes && !inOverview) return false;
      }

      // 3. Promo Deal Toggle check
      if (_onlyPromoDeals) {
        final hasPromo = (product.promoBadge ?? '').isNotEmpty;
        final isDiscounted = (product.regularPrice ?? (product.price ?? 0.0)) > (product.price ?? 0.0);
        if (!hasPromo && !isDiscounted) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeRoom = _boutiques[_selectedBoutiqueIndex];
    final products = _filteredProducts;

    return Scaffold(
      // 100% Opaque Dark Canvas — prevents any route pop ghosting!
      backgroundColor: const Color(0xFF0B0D12),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildDynamicHeader(activeRoom),
          _buildBoutiqueRoomSelector(),
          _buildScentAndDealControls(activeRoom, products.length),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFEAA134)),
              ),
            )
          else if (products.isEmpty)
            _buildEmptyResetState()
          else
            _buildProductSliverGrid(products, activeRoom),
        ],
      ),
    );
  }

  /// 1. Dynamic Ambient Header that morphs its glow to match the active Boutique Room
  Widget _buildDynamicHeader(BbwBoutiqueRoom room) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 155,
      backgroundColor: const Color(0xFF0B0D12),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: const [
        AppBarCartBadge(),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                room.gradientColors[0].withValues(alpha: 0.35),
                room.gradientColors[1].withValues(alpha: 0.15),
                const Color(0xFF0B0D12),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(52, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: room.gradientColors[0].withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: room.gradientColors[0].withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'BATH & BODY WORKS FLAGSHIP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    room.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF161922),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search ${room.title} or scent notes (e.g. vanilla, pine)...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: room.gradientColors[0], size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 2. Horizontal Boutique Room Cards (1 Card = 1 JSON File)
  /// FIXED: Increased height to 108 and tightened internal spacing to eliminate 2.0px bottom overflow
  Widget _buildBoutiqueRoomSelector() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 108,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _boutiques.length,
          itemBuilder: (context, index) {
            final room = _boutiques[index];
            final isSelected = _selectedBoutiqueIndex == index;

            return GestureDetector(
              onTap: () {
                if (_selectedBoutiqueIndex == index) return;
                HapticFeedback.mediumImpact();
                setState(() {
                  _selectedBoutiqueIndex = index;
                  _selectedScentNote = 'All Scents';
                  _onlyPromoDeals = false; // Reset promo filter when entering a new room
                });
                _loadActiveBoutique();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: room.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.07),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: room.gradientColors[0].withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          room.icon,
                          color: isSelected ? Colors.white : room.gradientColors[0],
                          size: 20,
                        ),
                        if (isSelected)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          room.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.white38,
                            fontSize: 10,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 3. Scent Spotlight Bar + 1-Tap Promo Toggle
  Widget _buildScentAndDealControls(BbwBoutiqueRoom activeRoom, int count) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scent Note Pills
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _scentSpotlights.length,
              itemBuilder: (context, index) {
                final scent = _scentSpotlights[index];
                final isSelected = _selectedScentNote == scent;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(scent),
                    selected: isSelected,
                    selectedColor: activeRoom.gradientColors[0],
                    backgroundColor: const Color(0xFF161922),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? Colors.white38 : Colors.white10,
                      ),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedScentNote = scent);
                    },
                  ),
                );
              },
            ),
          ),

          // Item Count & Mix-and-Match Deal Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$count Products Available',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _onlyPromoDeals = !_onlyPromoDeals);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _onlyPromoDeals
                          ? const Color(0xFFE11D48).withValues(alpha: 0.2)
                          : const Color(0xFF161922),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _onlyPromoDeals ? const Color(0xFFE11D48) : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_offer_rounded,
                          size: 14,
                          color: _onlyPromoDeals ? const Color(0xFFFB7185) : Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Special Offers Only',
                          style: TextStyle(
                            color: _onlyPromoDeals ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  /// 4. High-Performance Product Grid with Sensory Note Pills on the Card!
  Widget _buildProductSliverGrid(List<Product> products, BbwBoutiqueRoom room) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.52,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = products[index];
            return RepaintBoundary(
              child: _BbwSensoryProductCard(
                product: item,
                accentColor: room.gradientColors[0],
              ),
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }

  Widget _buildEmptyResetState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'No scents match that combination',
              style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedScentNote = 'All Scents';
                  _onlyPromoDeals = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFFEAA134)),
              label: const Text(
                'Show All Products in Room',
                style: TextStyle(color: Color(0xFFEAA134), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bespoke Product Card that highlights BBW's unique JSON fields:
/// Promo Badges, Top 2 Fragrance Notes, Unit Size, and Sale Price vs Regular Price.
class _BbwSensoryProductCard extends StatelessWidget {
  final Product product;
  final Color accentColor;

  const _BbwSensoryProductCard({
    required this.product,
    required this.accentColor,
  });

  /// Cleans scraper artifacts like "note: sweet peppermint" -> "sweet peppermint"
  static String _cleanNote(String raw) {
    return raw.replaceFirst(RegExp(r'^note:\s*', caseSensitive: false), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);
    final curPrice = (product.price ?? (product.salePrice ?? 16.95)).toDouble();
    final regPrice = (product.msrp ?? (product.regularPrice ?? curPrice)).toDouble();
    final hasPromo = (product.promoBadge ?? '').isNotEmpty;
    final hasDiscount = regPrice > curPrice && curPrice > 0;
    final topNotes = product.fragranceNotes
        .map(_cleanNote)
        .where((n) => n.isNotEmpty)
        .take(2)
        .toList();

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
          color: const Color(0xFF161922),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image + Floating Promo Badge
            Expanded(
              flex: 10,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.network(
                      product.imageUrl ?? '',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.spa_rounded, color: Colors.black26, size: 36),
                      ),
                    ),
                  ),
                  if (hasPromo || hasDiscount)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          hasPromo ? product.promoBadge! : 'SALE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Metadata + Sensory Fragrance Note Pills
            Expanded(
              flex: 12,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.unitShort ?? 'Standard',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (topNotes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: topNotes.map((note) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),

                    // Price & Quick Add Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasDiscount)
                              Text(
                                '\$${regPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9.5,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              '\$${curPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
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
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                ),
                              );
                            }

                            return Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 3),
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
                                      padding: EdgeInsets.symmetric(horizontal: 3),
                                      child: Icon(Icons.remove, color: Colors.white70, size: 13),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(
                                        color: gold,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      await CartService.instance.addProduct(product, 1);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 3),
                                      child: Icon(Icons.add, color: gold, size: 13),
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
            ),
          ],
        ),
      ),
    );
  }
}
