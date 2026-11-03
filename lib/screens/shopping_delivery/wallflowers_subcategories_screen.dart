// File: lib/screens/shopping_delivery/wallflowers_subcategories_screen.dart

import 'package:flutter/material.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../product_list_screen.dart';
import '../../widgets/store_app_bar.dart';

class WallflowersSubCategoriesScreen extends StatelessWidget {
  const WallflowersSubCategoriesScreen({super.key});

  static const gold = Color(0xFFE6B450);
  static const bg = Color(0xFF1F1F1F);
  static const card = Color(0xFF181818);

  static const List<Map<String, dynamic>> _subCategories = [
    {
      'name': 'Wallflowers Fragrance Refills',
      'icon': Icons.outlet_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw236a5863/hires/028008664.jpg?sw=600&q=60&format=auto',
      'description': 'Plug-in Fragrance Refills & 2-Pack Bulbs',
      'files': [
        'assets/data/all_wallflowers.json',
      ],
    },
    {
      'name': 'Wallflowers Plugs',
      'icon': Icons.power_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwdca7016c/hires/026634611.jpg?sw=600&q=60&format=auto',
      'description': 'Decorative Wallflower Plugs & Nightlight Diffusers',
      'files': [
        'assets/data/wallflowers_diffusers.json',
      ],
    },
    {
      'name': 'Infused Reeds',
      'icon': Icons.grass_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw236a5863/hires/028008664.jpg?sw=600&q=60&format=auto',
      'description': 'Flame-Free Reed Diffusers & Essential Oil Sticks',
      'files': [
        'assets/data/infused_reeds.json',
      ],
    },
    {
      'name': 'Room Sprays & Mists',
      'icon': Icons.air_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw95059f6a/hires/028016490.jpg?sw=600&q=60&format=auto',
      'description': 'Concentrated Room Sprays & Instant Fragrance Mists',
      'files': [
        'assets/data/room_sprays_mists.json',
      ],
    },
    {
      'name': 'Car Fragrance & Fresheners',
      'icon': Icons.directions_car_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwdbbf1a34/hires/028012637.jpg?sw=600&q=60&format=auto',
      'description': 'Car Fragrance Refills, Visor Clips & Vent Holders',
      'files': [
        'assets/data/car_fragrance_fresheners.json',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: const StoreAppBar(title: 'Wallflowers & Diffusers'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.70,
          ),
          itemCount: _subCategories.length,
          itemBuilder: (context, index) {
            final cat = _subCategories[index];
            final String name = cat['name'] as String;
            final String image = cat['image'] as String;
            final String desc = cat['description'] as String;
            final List<String> files = (cat['files'] as List).cast<String>();

            return Card(
              color: card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Colors.white12, width: 0.8),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductListScreen(
                        category: 'Wallflowers & Diffusers',
                        subCategory: name,
                        fileOverrides: files,
                        title: name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                  child: Column(
                    children: [
                      Container(
                        height: 105,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: RapidNetworkImage(
                            imageUrl: image,
                            width: double.infinity,
                            height: 105,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: Center(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              height: 1.15,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Center(
                          child: Text(
                            desc,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
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
