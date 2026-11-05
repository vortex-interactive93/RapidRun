// File: lib/screens/home/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/home_header.dart';
import '../search/global_search_screen.dart';
import '../../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../algorithms/collaborative_filtering.dart';
import '../../models/product.dart';
import '../../services/recent_items_service.dart';
import '../../widgets/product/product_card_v2.dart';
import 'widgets/service_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/config_service.dart';
import '../../widgets/catalog/independent_retailer_disclaimer.dart';
import '../../widgets/home/flagship_store_card.dart';
import '../../widgets/navigation/floating_cart_hud.dart';
import '../../services/favorites_cart_service.dart';
import '../shopping_delivery/aldi_store_screen.dart';
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
  String _sortMode = 'rating';
  String _filterStore = 'all';
  String? _deliveryAddress;

  @override
  void initState() {
    super.initState();
    final cf = buildSeededCF();
    _recEngine = RecommendationEngine(cf);
    _demoUserId = 'u1';
    ConfigService.instance.ensureListening();
    CartService.instance.addListener(_onCartStateChanged);
    _cfgSub = ConfigService.instance.stream.listen((_) {
      if (!mounted) return;
      _loadRecommendations();
      setState(() {});
    });
    _restorePrefs().then((_) => _bootstrap());
    _authSub = FirebaseService.userStream.listen((user) async {
      if (!mounted) return;
      setState(() {});
      if (user != null) {
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

  void _onCartStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await _recentItemsService.init();
    _refreshRecentProducts();
    await _loadRecommendations();
    await _loadAddress();
  }

  Future<void> _loadAddress() async {
    final u = FirebaseService.user;
    if (u == null) return;
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
        ...cfg.takeoutFeaturedIds.map(
          (id) => id.replaceAll('_', ' ').toLowerCase(),
        ),
      };
      var recs = _recEngine.recommendProducts(_demoUserId, topN: 12);
      if (_filterStore != 'all' && !allowedStores.contains(_filterStore)) {
        _filterStore = 'all';
      }
      if (_filterStore != 'all') {
        recs = recs
            .where((p) => (p.store ?? '').toLowerCase() == _filterStore)
            .toList();
      }
      recs = recs
          .where((p) => allowedStores.contains((p.store ?? '').toLowerCase()))
          .toList();
      recs.sort((a, b) {
        if (_sortMode == 'name') {
          return a.name.compareTo(b.name);
        }
        final ar = a.rating ?? 0;
        final br = b.rating ?? 0;
        final r = br.compareTo(ar);
        if (r != 0) return r;
        return a.name.compareTo(b.name);
      });
      _recommendations = recs.take(6).toList();
    });
  }

  Future<void> _onProductTapped(Product p) async {
    await _recentItemsService.add(p.id);
    setState(() => _refreshRecentProducts());
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_onCartStateChanged);
    _authSub?.cancel();
    _cfgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F1115),
      body: Stack(
        children: [
          Column(
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _loadRecommendations(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ServiceGrid(
                            onNavigate: (route) =>
                                Navigator.pushNamed(context, route),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _dualFlagshipSection(),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _recommendationSection(),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _favoritesRail(),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _recentlyViewedSection(),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: IndependentRetailerDisclaimer(),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Floating Glass Cart HUD
          FloatingCartHUD(
            itemCount: cart.totalItems,
            subtotal: cart.subtotal,
            onCheckout: () => Navigator.pushNamed(context, '/cart'),
          ),
        ],
      ),
    );
  }

  Widget _dualFlagshipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Flagship Destinations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 1. Bath & Body Works Flagship Card
        FlagshipStoreCard(
          type: FlagshipType.bathAndBodyWorks,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BbwStoreScreen(),
              ),
            );
          },
        ),

        // 2. ALDI Market Flagship Card
        FlagshipStoreCard(
          type: FlagshipType.aldi,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AldiStoreScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _recommendationSection() {
    const gold = Color(0xFFE5A93C);

    final recommendedProducts = [
      {
        'id': 'bbw_028034046',
        'name': 'A Thousand Wishes Body Wash',
        'store': 'Bath & Body Works',
        'price': 16.95,
        'size': '10 fl oz',
        'imageUrl': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwf68ba573/hires/028034046.jpg?sw=480&q=75&format=auto',
      },
      {
        'id': 'bbw_028011404',
        'name': 'Sweetest Song Body Cream',
        'store': 'Bath & Body Works',
        'price': 18.95,
        'size': '8 oz',
        'imageUrl': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwc03c50ab/hires/028011404.jpg?sw=480&q=75&format=auto',
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
                  color: const Color(0xFF14171E),
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
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final p = Product(
                              id: product['id'] as String,
                              name: product['name'] as String,
                              price: product['price'] as double,
                              imageUrl: product['imageUrl'] as String,
                              unit: product['size'] as String,
                              unitShort: product['size'] as String,
                            );
                            await CartService.instance.addProduct(p, 1);
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
