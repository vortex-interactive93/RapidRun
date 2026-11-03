import 'package:flutter/material.dart';
import 'aldi_store_screen.dart';
import 'baby_items_subcategories_screen.dart';
import 'bath_and_body_works_store_screen.dart';
import 'walmart_store_screen.dart';
import '../catalog/store_aisle_screen.dart';
import '../catalog/bbw_store_hub_screen.dart';
import '../catalog/bbw_store_screen.dart';
import '../../services/config_service.dart';

class ShoppingDeliveryScreen extends StatefulWidget {
  const ShoppingDeliveryScreen({Key? key}) : super(key: key);

  @override
  State<ShoppingDeliveryScreen> createState() => _ShoppingDeliveryScreenState();
}

class _ShoppingDeliveryScreenState extends State<ShoppingDeliveryScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure we begin listening to remote config for dynamic gating.
    ConfigService.instance.ensureListening();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    final cfg = ConfigService.instance.current;
    return Scaffold(
      backgroundColor: const Color(0xFF1f1f1f),
      appBar: AppBar(
        title: const Text(
          'Shopping & Delivery',
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
          final visible = retailers
              .where(
                (r) => c.shoppingFeaturedNames.contains(
                  (r['name']?.toString().toLowerCase() ?? ''),
                ),
              )
              .toList(growable: false);
          if (visible.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No retailers available right now.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1, // Adjusted to make the grid square
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final retailer = visible[index];
                final logoPath = retailer['logo']; // may be null (String?)
                return Card(
                  color: const Color(0xFF181818),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      if (retailer['name'] == 'Aldi') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AldiStoreScreen(),
                          ),
                        );
                      } else if (retailer['name'] == 'Baby Items') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const BabyItemsSubcategoriesScreen(),
                          ),
                        );
                      } else if (retailer['name'] == 'Bath & Body Works') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BbwStoreScreen(),
                          ),
                        );
                      } else if (retailer['name'] == 'Walmart') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalmartStoreScreen(),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0), // Reduced padding
                      child: Center(
                        child: logoPath == null
                            ? const Icon(
                                Icons.shopping_bag,
                                color: gold,
                                size: 42,
                              )
                            : Image.asset(logoPath, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

const retailers = [
  {'name': 'Aldi', 'logo': 'assets/logos/aldi_logo.png'},
  {'name': 'Target', 'logo': 'assets/logos/target_logo.png'},
  {'name': 'Walmart', 'logo': 'assets/logos/walmart_logo.png'},
  {
    'name': 'Bath & Body Works',
    'logo': 'assets/logos/bath_and_body_works_logo.png',
  },
  {'name': 'Baby Items', 'logo': null},
];

// Old floating search FAB removed as in-category animated search bar handles search UX.
