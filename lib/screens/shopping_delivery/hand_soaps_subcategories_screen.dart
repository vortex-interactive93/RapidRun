// File: lib/screens/shopping_delivery/hand_soaps_subcategories_screen.dart

import 'package:flutter/material.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../product_list_screen.dart';
import '../../widgets/store_app_bar.dart';

class HandSoapsSubCategoriesScreen extends StatelessWidget {
  const HandSoapsSubCategoriesScreen({super.key});

  static const gold = Color(0xFFE6B450);
  static const bg = Color(0xFF1F1F1F);
  static const card = Color(0xFF181818);

  static const List<Map<String, dynamic>> _subCategories = [
    {
      'name': 'Foaming Soaps',
      'icon': Icons.soap_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw33f12c1b/hires/028003595.jpg?sw=600&q=60&format=auto',
      'description': 'Gentle & Clean Foaming Hand Soaps',
      'files': [
        'assets/data/all_hand_soaps.json',
      ],
    },
    {
      'name': 'Gel Soaps',
      'icon': Icons.clean_hands_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwa53d3e90/hires/028029701.jpg?sw=600&q=60&format=auto',
      'description': 'Cleansing Gel Hand Soaps with Essential Oils',
      'files': [
        'assets/data/all_hand_soaps.json',
      ],
    },
    {
      'name': 'Moisturizing Hand Soaps',
      'icon': Icons.water_drop_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw33f12c1b/hires/028003595.jpg?sw=600&q=60&format=auto',
      'description': 'Nourishing & Hydrating Cream Hand Soaps',
      'files': [
        'assets/data/all_hand_soaps.json',
      ],
    },
    {
      'name': 'Revitalizing Hand Soaps',
      'icon': Icons.auto_awesome_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwa53d3e90/hires/028029701.jpg?sw=600&q=60&format=auto',
      'description': 'Exfoliating & Revitalizing Hand Soaps',
      'files': [
        'assets/data/all_hand_soaps.json',
      ],
    },
    {
      'name': 'Foaming Hand Soaps Refills',
      'icon': Icons.recycling_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dw33f12c1b/hires/028003595.jpg?sw=600&q=60&format=auto',
      'description': 'Eco-Friendly Carton Refills (36 fl oz)',
      'files': [
        'assets/data/all_hand_soaps.json',
      ],
    },
    {
      'name': 'Soap Holders & Dispensers',
      'icon': Icons.sanitizer_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwdca7016c/hires/026634611.jpg?sw=600&q=60&format=auto',
      'description': 'Decorative Soap Sleeve Holders & Dispensers',
      'files': [
        'assets/data/hand_soaps_sanitizers.json',
      ],
    },
    {
      'name': 'All Hand Sanitizers',
      'icon': Icons.health_and_safety_outlined,
      'image': 'https://www.bathandbodyworks.com/dw/image/v2/BBDL_PRD/on/demandware.static/-/Sites-master-catalog/default/dwfc5cc153/hires/028004878.jpg?sw=600&q=60&format=auto',
      'description': 'PocketBac Sanitizers, Spray Sanitizers & Holders',
      'files': [
        'assets/data/all_hand_sanitizers.json',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: const StoreAppBar(title: 'Hand Soaps & Sanitizers'),
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
                        category: 'Hand Soaps & Sanitizers',
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
