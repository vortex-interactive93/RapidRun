import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import '../../widgets/reactive_cart_badge.dart'; // removed with new header
import 'widgets/home_header.dart';
import '../search/global_search_screen.dart';
import '../../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../algorithms/collaborative_filtering.dart';
import '../../models/product.dart';
import '../../services/recent_items_service.dart';
// ProductChip legacy import removed during migration to ProductCardV2.
import '../../widgets/product/product_card_v2.dart';
import 'widgets/service_grid.dart';
import '../../widgets/shimmer_box.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/tokens.dart';
import '../../services/config_service.dart';
import '../../widgets/catalog/independent_retailer_disclaimer.dart';
import '../../widgets/home/featured_store_card.dart';
import '../store/unified_store_catalog_screen.dart';
import '../catalog/store_aisle_screen.dart';
import '../catalog/bbw_store_hub_screen.dart';
import '../catalog/bbw_store_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final RecommendationEngine _recEngine;
  late final String _demoUserId;
  List<Product> _recommendations = const [];
  final RecentItemsService _recentItemsService = RecentItemsService();
  List<Product> _recentProducts = const [];
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppRemoteConfig>? _cfgSub;
  String _sortMode = 'rating'; // rating | name
  String _filterStore = 'all';
  String? _deliveryAddress; // loaded from user profile

  // Single visual style (classic dark + gold)

  @override
  void initState() {
    super.initState();
    final cf = buildSeededCF();
    _recEngine = RecommendationEngine(cf);
    _demoUserId = 'u1';
    // Start listening for remote config updates (dynamic store gating).
    ConfigService.instance.ensureListening();
    _cfgSub = ConfigService.instance.stream.listen((_) {
      if (!mounted) return;
      _loadRecommendations();
      setState(() {}); // rebuild header filters when config changes
    });
    _restorePrefs().then((_) => _bootstrap());
    // Listen to auth changes so UI reflects sign-in / sign-out immediately.
    _authSub = FirebaseService.userStream.listen((user) async {
      if (!mounted) return;
      setState(() {});
      if (user != null) {
        // Check completion flag.
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final completed = snap.data()?['profileCompleted'] == true;
          if (!completed) {
            if (ModalRoute.of(context)?.isCurrent ?? true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushNamed(context, '/secure-setup');
              });
            }
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _bootstrap() async {
    await _recentItemsService.init();
    _refreshRecentProducts();
    await _loadRecommendations();
    await _loadAddress();
  }

  Future<void> _loadAddress() async {
    final u = FirebaseService.user;
    if (u == null) return; // guest
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      final addr = (snap.data()?['deliveryAddress'] ?? '').toString().trim();
      if (mounted) {
        setState(() => _deliveryAddress = addr.isEmpty ? null : addr);
      }
    } catch (_) {}
  }

  Future<void> _restorePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _sortMode = prefs.getString('rec_sort_mode_v1') ?? _sortMode;
        _filterStore = prefs.getString('rec_filter_store_v1') ?? _filterStore;
      });
    } catch (_) {}
  }

  Future<void> _persistPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rec_sort_mode_v1', _sortMode);
      await prefs.setString('rec_filter_store_v1', _filterStore);
    } catch (_) {}
  }

  void _refreshRecentProducts() {
    final all = {for (final p in ProductRepository.sampleProducts) p.id: p};
    _recentProducts = _recentItemsService.ids
        .map((id) => all[id])
        .whereType<Product>()
        .toList();
  }

  Future<void> _loadRecommendations() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() {
      final cfg = ConfigService.instance.current;
      final allowedStores = <String>{
        ...cfg.shoppingFeaturedNames.map((s) => s.toLowerCase()),
        // Map takeout ids to a display-like name best-effort: taco_bell -> taco bell
        ...cfg.takeoutFeaturedIds.map(
          (id) => id.replaceAll('_', ' ').toLowerCase(),
        ),
      };
      var recs = _recEngine.recommendProducts(_demoUserId, topN: 12);
      // Clamp filter if it becomes disallowed by remote config
      if (_filterStore != 'all' && !allowedStores.contains(_filterStore)) {
        _filterStore = 'all';
      }
      if (_filterStore != 'all') {
        recs = recs
            .where((p) => (p.store ?? '').toLowerCase() == _filterStore)
            .toList();
      }
      // Also remove any recs from disallowed stores to keep the view consistent
      recs = recs
          .where((p) => allowedStores.contains((p.store ?? '').toLowerCase()))
          .toList();
      recs.sort((a, b) {
        if (_sortMode == 'name') {
          return a.name.compareTo(b.name);
        }
        // default rating desc
        final ar = a.rating ?? 0;
        final br = b.rating ?? 0;
        final r = br.compareTo(ar);
        if (r != 0) return r; // then name asc
        return a.name.compareTo(b.name);
      });
      _recommendations = recs.take(6).toList();
    });
  }

  Future<void> _onProductTapped(Product p) async {
    await _recentItemsService.add(p.id);
    setState(() => _refreshRecentProducts());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar('Opened ${p.name} (demo)', icon: Icons.info_outline),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cfgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final user = FirebaseService.user; // no longer used directly; header handles auth greeting
    // cart instance no longer needed here after mini cart removal
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1f1f1f),
      body: Column(
        children: [
          HomeHeader(
            onCartTap: () => Navigator.pushNamed(context, '/cart'),
            onSearchTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
            address: _deliveryAddress,
            onAddressTap: () =>
                showEditAddressSheet(context).then((_) => _loadAddress()),
            // Reduced bottom padding to pull content closer
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadRecommendations(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                // Reduced top padding to bring service cards closer to header
                // Top padding reduced further (8 -> 0) to move cards up
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // WelcomeCard removed per design update (space reclaimed)
                    ServiceGrid(
                      onNavigate: (route) =>
                          Navigator.pushNamed(context, route),
                    ),
                    const SizedBox(height: 24),
                    _featuredStoresSection(),
                    const SizedBox(height: 24),
                    _recommendationSection(),
                    const SizedBox(height: 32),
                    _favoritesRail(),
                    const SizedBox(height: 32),
                    _recentlyViewedSection(),
                    const IndependentRetailerDisclaimer(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featuredStoresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured Concierge Partners',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FeaturedStoreCard(
                storeName: 'Bath & Body Works',
                category: 'Fragrance & Body Care',
                deliveryEta: '⚡ 20–30 min',
                imageUrl: 'https://images.unsplash.com/photo-1547887537-6158d64c35b3?w=500&q=80',
                rating: 4.9,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BbwStoreScreen(),
                    ),
                  );
                },
              ),
              FeaturedStoreCard(
                storeName: 'ALDI Grocery & Fresh',
                category: 'Pantry & Produce',
                deliveryEta: '⚡ 25–35 min',
                imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500&q=80',
                rating: 4.8,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UnifiedStoreCatalogScreen(storeName: 'ALDI Grocery & Fresh'),
                    ),
                  );
                },
              ),
              FeaturedStoreCard(
                storeName: 'Walmart Supercenter',
                category: 'Everyday Essentials',
                deliveryEta: '⚡ 30–40 min',
                imageUrl: 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=500&q=80',
                rating: 4.7,
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recommendationSection() {
    const gold = Color(0xFFE6B450);

    final recommendedProducts = [
      {
        'id': 'bbw_028005120',
        'name': 'A Thousand Wishes Mist',
        'store': 'Bath & Body Works',
        'price': 4.73,
        'size': '8 fl oz',
        'imageUrl': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw1ef511b8/crop/028005120_crop.jpg?sw=500&sh=600&sm=fit',
      },
      {
        'id': 'bbw_028028909',
        'name': 'In the Stars Mist',
        'store': 'Bath & Body Works',
        'price': 5.95,
        'size': '8 fl oz',
        'imageUrl': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw063e5270/crop/028028909_crop.jpg?sw=500&sh=600&sm=fit',
      },
      {
        'id': 'aldi_strawberries_16oz',
        'name': 'Fresh Strawberries',
        'store': 'ALDI',
        'price': 2.49,
        'size': '1 lb pkg',
        'imageUrl': 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=500&auto=format&fit=crop&q=80',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended For You',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 215,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendedProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = recommendedProducts[index];
              return Container(
                width: 154,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF171A21),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 94,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product['imageUrl'] as String,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, color: Colors.black26),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product['name'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      product['size'] as String,
                      style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${(product['price'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${product['name']} to cart'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFF1E2129),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.add, size: 16, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _favoritesRail() {
    // Placeholder favorites list pulling from recent items for now. In the
    // future, wire to FavoritesService (not shown here). If empty, collapse.
    final favs = _recentProducts.take(10).toList();
    if (favs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Favorites',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/favorites'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: favs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final p = favs[i];
              return SizedBox(
                width: 140,
                child: ProductCardV2(
                  product: p,
                  onTap: () => _onProductTapped(p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _recommendationHeader() {
    final cfg = ConfigService.instance.current;
    final allowed = <String>{
      ...cfg.shoppingFeaturedNames.map((s) => s.toLowerCase()),
      ...cfg.takeoutFeaturedIds.map(
        (id) => id.replaceAll('_', ' ').toLowerCase(),
      ),
    };
    final stores = [
      'all',
      ...{
        for (final p in ProductRepository.sampleProducts)
          (p.store ?? '').toLowerCase(),
      }.where((s) => s.isNotEmpty && allowed.contains(s)),
    ];
    return Row(
      children: [
        Expanded(
          child: Text(
            'Recommended For You',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _filterStore,
            dropdownColor: const Color(0xFF2a2a2a),
            items: stores
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s == 'all' ? 'All Stores' : s,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _filterStore = v;
                _persistPrefs();
              });
              _loadRecommendations();
            },
          ),
        ),
        const SizedBox(width: 4),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _sortMode,
            dropdownColor: const Color(0xFF2a2a2a),
            items: const [
              DropdownMenuItem(
                value: 'rating',
                child: Text('Rating', style: TextStyle(fontSize: 12)),
              ),
              DropdownMenuItem(
                value: 'name',
                child: Text('Name', style: TextStyle(fontSize: 12)),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _sortMode = v;
                _persistPrefs();
              });
              _loadRecommendations();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadRecommendations,
        ),
      ],
    );
  }

  Widget _recentlyViewedSection() {
    if (_recentProducts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recently Viewed',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Recently viewed items will appear here as you open products.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recently Viewed',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = _recentProducts[index];
              return SizedBox(
                width: 160,
                child: ProductCardV2(
                  product: p,
                  onTap: () => _onProductTapped(p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Legacy _UserAvatar widget removed (now handled inside modular header components when needed)
