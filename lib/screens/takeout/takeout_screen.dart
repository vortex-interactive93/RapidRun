import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/config_service.dart';
// Product detail import no longer needed here after restoring Panda -> search flow.

/// High-level Takeout landing screen: shows restaurant partners (initially Taco Bell)
/// and surfaces its parent categories for quick drill-in. Additional restaurants can
/// append to [_restaurants] later with metadata + category asset mapping.
class TakeoutScreen extends StatefulWidget {
  const TakeoutScreen({super.key});
  @override
  State<TakeoutScreen> createState() => _TakeoutScreenState();
}

class _TakeoutScreenState extends State<TakeoutScreen> {
  // Limit visible restaurants for initial rollout.
  final List<_RestaurantModel> _restaurants = const [
    _RestaurantModel(
      id: 'taco_bell',
      display: 'Taco Bell',
      logoAsset: 'assets/restaurant_logos/tacobell_logo.png',
      categoryJson: 'assets/stores/taco_bell/taco_bell_categories.json',
      comingSoon: false,
    ),
    _RestaurantModel(
      id: 'panda_express',
      display: 'Panda Express',
      logoAsset: 'assets/restaurant_logos/panda_express_logo.png',
      categoryJson: 'assets/stores/panda_express/panda-express-categories.json',
      comingSoon: false,
    ),
  ];
  bool _loading = true;
  final Map<String, List<_CategoryDef>> _catsByRestaurant = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    ConfigService.instance.ensureListening();
    _load();
  }

  Future<void> _load() async {
    final futures = <Future>[];
    for (final r in _restaurants) {
      if (r.comingSoon || r.categoryJson.isEmpty) continue;
      futures.add(() async {
        try {
          final raw = await rootBundle.loadString(r.categoryJson);
          final decoded = json.decode(raw) as Map<String, dynamic>;
          final list = (decoded['parentCategories'] as List?) ?? [];
          final parsed = list
              .whereType<Map>()
              .map(
                (m) => _CategoryDef(
                  id: (m['id'] ?? '').toString(),
                  label: (m['label'] ?? '').toString(),
                  icon: (m['icon'] ?? '').toString(),
                ),
              )
              .where((c) => c.id.isNotEmpty && c.label.isNotEmpty)
              .toList();
          if (mounted) setState(() => _catsByRestaurant[r.id] = parsed);
        } catch (e) {
          debugPrint('[Takeout] category load failed for ${r.id}: $e');
        }
      }());
    }
    if (mounted) setState(() => _loading = false);
    try {
      await Future.wait(futures);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    final cfg = ConfigService.instance.current;
    return Scaffold(
      backgroundColor: const Color(0xFF1f1f1f),
      appBar: AppBar(
        title: const Text(
          'Takeout',
          style: TextStyle(color: gold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF181818),
        iconTheme: const IconThemeData(color: gold),
      ),
      body: StreamBuilder<AppRemoteConfig>(
        stream: ConfigService.instance.stream,
        initialData: cfg,
        builder: (context, snap) {
          final c = snap.data ?? cfg;
          final ids = c.takeoutFeaturedIds.toSet();
          final visibleNow = _restaurants
              .where((r) => ids.contains(r.id))
              .toList();
          return _loading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : (visibleNow.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  'No restaurants available right now.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1,
                                    ),
                                itemCount: visibleNow.length,
                                itemBuilder: (context, index) {
                                  final r = visibleNow[index];
                                  final tap = r.comingSoon
                                      ? () => _showComingSoon(context)
                                      : () => Navigator.pushNamed(
                                          context,
                                          '/store-search/${r.id}',
                                        );
                                  return _RestaurantGridCard(
                                    restaurant: r,
                                    categoryCount:
                                        (_catsByRestaurant[r.id] ?? const [])
                                            .length,
                                    onTap: tap,
                                    onLongPress: () {
                                      if (r.comingSoon) return;
                                      final cats =
                                          _catsByRestaurant[r.id] ?? const [];
                                      if (cats.isEmpty) return;
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: const Color(
                                          0xFF252525,
                                        ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(24),
                                          ),
                                        ),
                                        builder: (_) => Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: SingleChildScrollView(
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                for (final c in cats)
                                                  _CategoryPill(
                                                    def: c,
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      Navigator.pushNamed(
                                                        context,
                                                        '/store-search/${r.id}',
                                                        arguments: {
                                                          'prefillCategory':
                                                              c.label,
                                                        },
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            )));
        },
      ),
    );
  }
}

class _RestaurantModel {
  final String id;
  final String display;
  final String logoAsset;
  final String categoryJson;
  final bool comingSoon;
  const _RestaurantModel({
    required this.id,
    required this.display,
    required this.logoAsset,
    required this.categoryJson,
    this.comingSoon = false,
  });
}

class _CategoryDef {
  final String id;
  final String label;
  final String icon;
  const _CategoryDef({
    required this.id,
    required this.label,
    required this.icon,
  });
  IconData materialIcon() {
    const mapping = <String, IconData>{
      'star': Icons.star_outline,
      'taco': Icons.fastfood,
      'fastfood': Icons.fastfood,
      'lunch_dining': Icons.lunch_dining,
      'restaurant': Icons.restaurant,
      'restaurant_menu': Icons.restaurant_menu,
      'bakery_dining': Icons.bakery_dining,
      'local_drink': Icons.local_drink,
      'new_releases': Icons.new_releases,
      'shopping_bag': Icons.shopping_bag,
      'savings': Icons.savings,
      'takeout_dining': Icons.takeout_dining,
      'workspace_premium': Icons.workspace_premium,
      'icecream': Icons.icecream,
      'flatware': Icons.flatware,
      'local_pizza': Icons.local_pizza,
      'groups': Icons.groups,
      'eco': Icons.eco,
      'rice_bowl': Icons.rice_bowl,
      'free_breakfast': Icons.free_breakfast,
    };
    return mapping[icon] ?? Icons.label_outline;
  }
}

class _RestaurantGridCard extends StatelessWidget {
  final _RestaurantModel restaurant;
  final int categoryCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _RestaurantGridCard({
    required this.restaurant,
    required this.categoryCount,
    required this.onTap,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    final muted = restaurant.comingSoon ? Colors.white24 : Colors.white54;
    return Opacity(
      opacity: restaurant.comingSoon ? 0.7 : 1,
      child: Card(
        color: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: restaurant.comingSoon ? null : onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Image.asset(
                          restaurant.logoAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => const Icon(
                            Icons.restaurant_menu,
                            color: Color(0xFFE6B450),
                            size: 42,
                          ),
                        ),
                      ),
                      if (restaurant.comingSoon)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Coming Soon',
                              style: TextStyle(
                                color: gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  restaurant.display,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  restaurant.comingSoon
                      ? 'Stay tuned'
                      : '$categoryCount Categories',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final _CategoryDef def;
  final VoidCallback onTap;
  const _CategoryPill({required this.def, required this.onTap});
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    return Material(
      color: gold.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(def.materialIcon(), size: 16, color: gold),
              const SizedBox(width: 6),
              Text(
                def.label,
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showComingSoon(BuildContext context) {
  final scaffold = ScaffoldMessenger.of(context);
  scaffold.clearSnackBars();
  scaffold.showSnackBar(
    const SnackBar(
      content: Text('We\'re working to add this restaurant.'),
      duration: Duration(seconds: 2),
    ),
  );
}
