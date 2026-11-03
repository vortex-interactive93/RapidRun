// File: lib/screens/shopping_delivery/bath_and_body_works_store_screen.dart

import 'package:flutter/material.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../product_list_screen.dart';
import '../../widgets/store_app_bar.dart';
import 'body_care_subcategories_screen.dart';
import 'wallflowers_subcategories_screen.dart';
import 'hand_soaps_subcategories_screen.dart';
import 'mens_shop_subcategories_screen.dart';

class BathAndBodyWorksStoreScreen extends StatelessWidget {
  const BathAndBodyWorksStoreScreen({super.key});

  static const gold = Color(0xFFE6B450);
  static const bg = Color(0xFF1F1F1F);
  static const card = Color(0xFF181818);

  static const List<Map<String, dynamic>> _categories = [
    {
      'name': 'Fragrance',
      'icon': Icons.spa_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw8bcc5191/hires/028029081.jpg?sw=600&q=60&format=auto',
      'files': [
        'assets/data/all_fragrance.json',
        'assets/data/Body_Sprays_Mists.json',
        'assets/data/Perfume_Cologne.json',
      ],
      'description': 'Body Sprays, Mists, Perfume & Fine Fragrances',
    },
    {
      'name': 'Body Care',
      'icon': Icons.sanitizer_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw43534b9c/hires/028005118.jpg?sw=600&q=60&format=auto',
      'files': [
        'assets/data/body_care.json',
      ],
      'description': 'Moisturizers, Bath & Shower, Minis & Lip Care',
    },
    {
      'name': 'Candles',
      'icon': Icons.local_fire_department_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwb8f180ab/hires/028030716.jpg?sw=600&q=60&format=auto',
      'files': [
        'assets/data/candles.json',
        'assets/data/3_wick_candles.json',
        'assets/data/single_wick_candles.json',
      ],
      'description': '3-Wick & 4-Wick Candles, Single-Wick & Accessories',
    },
    {
      'name': 'Wallflowers & Diffusers',
      'icon': Icons.outlet_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw236a5863/hires/028008664.jpg?sw=600&q=60&format=auto',
      'files': [
        'assets/data/wallflowers_diffusers.json',
        'assets/data/all_wallflowers.json',
      ],
      'description': 'Refills, Plugs, Reeds, Room Sprays & Car Care',
    },
    {
      'name': 'Hand Soaps & Sanitizers',
      'icon': Icons.soap_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw33f12c1b/hires/028003595.jpg?sw=600&q=60&format=auto',
      'files': [
        'assets/data/hand_soaps_sanitizers.json',
        'assets/data/all_hand_soaps.json',
        'assets/data/all_hand_sanitizers.json',
      ],
      'description': 'Foaming Hand Soaps, Gel Soaps & PocketBac Sanitizers',
    },
    {
      'name': "The Men's Shop",
      'icon': Icons.dry_cleaning_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw5b5fd874/hires/028013138.jpg?sw=600&q=60&format=auto',
      'files': [
        'assets/data/mens_shop.json',
      ],
      'description': "Men's Colognes, 3-in-1 Body Wash, Body Sprays & Cream",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: const StoreAppBar(title: 'Bath & Body Works'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.70,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
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
                  if (name == 'Body Care') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BodyCareSubCategoriesScreen(),
                      ),
                    );
                    return;
                  }

                  if (name == 'Wallflowers & Diffusers') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WallflowersSubCategoriesScreen(),
                      ),
                    );
                    return;
                  }

                  if (name == 'Hand Soaps & Sanitizers') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HandSoapsSubCategoriesScreen(),
                      ),
                    );
                    return;
                  }

                  if (name == "The Men's Shop" || name == "Men's Shop") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MensShopSubCategoriesScreen(),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductListScreen(
                        category: name,
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
                      // 1. Off-White Studio Canvas
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

                      // 2. Full Title Display
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

                      // 3. Subtitle Summary
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
