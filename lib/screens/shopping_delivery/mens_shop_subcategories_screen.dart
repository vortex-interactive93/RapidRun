// File: lib/screens/shopping_delivery/mens_shop_subcategories_screen.dart

import 'package:flutter/material.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../product_list_screen.dart';
import '../../widgets/store_app_bar.dart';

class MensShopSubCategoriesScreen extends StatelessWidget {
  const MensShopSubCategoriesScreen({super.key});

  static const gold = Color(0xFFE6B450);
  static const bg = Color(0xFF1F1F1F);
  static const card = Color(0xFF181818);

  static const List<Map<String, dynamic>> _subCategories = [
    {
      'name': "All Men's Body Care",
      'icon': Icons.dry_cleaning_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw5b5fd874/hires/028013138.jpg?sw=600&q=60&format=auto',
      'description': 'Deodorizing Body Sprays, Colognes, Wash, Creams & Soaps',
      'files': [
        'assets/data/mens_shop.json',
      ],
    },
    {
      'name': "Men's fragrance",
      'icon': Icons.spa_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw291f9292/hires/028013178.jpg?sw=600&q=60&format=auto',
      'description': "Men's Colognes, Mini Colognes & Travel Sprays",
      'files': [
        'assets/data/mens_shop.json',
        'assets/data/Perfume_Cologne.json',
      ],
    },
    {
      'name': 'Body Wash',
      'icon': Icons.shower_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw5b5fd874/hires/028013138.jpg?sw=600&q=60&format=auto',
      'description': '3-in-1 Hair, Face & Body Wash',
      'files': [
        'assets/data/mens_shop.json',
      ],
    },
    {
      'name': 'Moisturizers',
      'icon': Icons.water_drop_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw5b5fd874/hires/028013138.jpg?sw=600&q=60&format=auto',
      'description': 'Ultimate Hydration Body Cream & Body Lotion',
      'files': [
        'assets/data/mens_shop.json',
      ],
    },
    {
      'name': 'Deodorant',
      'icon': Icons.shield_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw291f9292/hires/028013178.jpg?sw=600&q=60&format=auto',
      'description': '24-Hour Antiperspirant Deodorants',
      'files': [
        'assets/data/mens_shop.json',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: const StoreAppBar(title: "The Men's Shop"),
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
                        category: "The Men's Shop",
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
