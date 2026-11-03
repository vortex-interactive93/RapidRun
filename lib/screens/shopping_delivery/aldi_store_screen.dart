import 'package:flutter/material.dart';
import 'package:rapidrun/screens/product_list_screen.dart' as product_list;
import 'package:rapidrun/data/aldi_category_model.dart';
import 'baby_items_subcategories_screen.dart';
import '../../widgets/store_app_bar.dart';

class AldiStoreScreen extends StatefulWidget {
  const AldiStoreScreen({Key? key}) : super(key: key);
  @override
  State<AldiStoreScreen> createState() => _AldiStoreScreenState();
}

class _AldiStoreScreenState extends State<AldiStoreScreen> {
  late Future<AldiCategoryData> _future;
  @override
  void initState() {
    super.initState();
    _future = AldiCategoryData.load();
  }

  static const gold = Color(0xFFE6B450);
  static const bg = Color(0xFF1f1f1f);
  static const card = Color(0xFF181818);

  // Official ALDI parent category images from site asset mapping
  static const Map<String, String> _categoryImages = {
    'Meat & Seafood':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/c24vUmuVRCCoKy71GPNh_c703d7fd-fdda-43eb-ae30-fabd7d020bd2.jpg',
    'Fresh Meat & Seafood':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/c24vUmuVRCCoKy71GPNh_c703d7fd-fdda-43eb-ae30-fabd7d020bd2.jpg',
    'Fresh Produce':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/A8wsDXrQgazlcvpEXZNm_32c637ce-55f8-472d-a14b-946cfdf0678b.jpg',
    'Dairy & Eggs':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/yKW20o7rQyava0zI929q_7ebe6c89-7951-4593-8122-a7038281e379.jpg',
    'Snacks':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/eWaalmXCSfex92q5rxdL_b31d0824-6bfb-465c-95d8-f67416871b00.jpg',
    'Snacks & Candy':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/eWaalmXCSfex92q5rxdL_b31d0824-6bfb-465c-95d8-f67416871b00.jpg',
    'Frozen Foods':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/lwPj47HDQtqvj3cdbTjA_464d3287-714e-43d3-b414-e1e661d8ef21.jpg',
    'Frozen':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/lwPj47HDQtqvj3cdbTjA_464d3287-714e-43d3-b414-e1e661d8ef21.jpg',
    'Bakery & Bread':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/wG61iFmQGq8xGTizMEg2_5b1822a6-2c91-4cf2-a993-e96f6151ad43.jpg',
    'Baking Essentials':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/YNn2BXQFTLqYKP1h4KNB_76ad9262-47df-46ad-aaf4-ae356976f338.jpg',
    'Pantry Essentials':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/CjzcGoX6SsCw3v1JyV7A_52de56d0-7dc6-44ac-b588-efc9624c7aa1.jpg',
    'Beverages':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/JsYzrM8GTlqSGDz5ptng_3183154e-f986-4e07-98b5-330787c43d87.jpg',
    'Breakfast & Cereals':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/LszcphSuQBKSeV7Ts3Pw_6eb861d3-c591-4bdd-b919-dd69a1a803ea.jpg',
    'Breakfast & Cereal':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/LszcphSuQBKSeV7Ts3Pw_6eb861d3-c591-4bdd-b919-dd69a1a803ea.jpg',
    'Deli':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/aZNrJH4bRki63AOfED6J_17907794-7e1a-469e-aea7-a5090c93a94e.jpg',
    'Prepared Foods':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/bBU2togySaWFrqkWxDeD_bfbdb773-d94b-473e-a65b-2493bd959029.jpg',
    'Alcohol':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/g0ypGIVnQvaV694ozaf8_be37c56d-17b5-45d3-a3ad-58870ac6d729.jpg',
    'Household Essentials':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/jhXTgV3rTiqr3XS2gkyS_9e9014c4-083e-4912-823a-fe0ba3dfbdd7.jpg',
    'Personal Care':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/UVjItM6cTGOGuELOO8Xy_017a1352-8a40-44c8-b7b8-271673c50732.jpg',
    'Pet Supplies':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/a9Xfjrt9SMK6Z6nrHjov_d5369736-7585-4af2-ba34-51a2b5b33d37.jpg',
    'Baby Items':
        'https://www.instacart.com/image-server/www.instacart.com/assets/domains/store_configuration/creative_asset/1672/kV4SSLpSmGEtRdh2RhNB_94e1a900-d421-429f-a254-f54a4f8216e8.jpg',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: const StoreAppBar(title: 'Aldi Store'),
      body: FutureBuilder<AldiCategoryData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: gold));
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          final data = snap.data;
          if (data == null || data.categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories found.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          final cats = data.categories;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.95,
              ),
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final c = cats[i];
                final displayName = c.name == 'Pets Supplies'
                    ? 'Pet Supplies'
                    : c.name;
                final imageUrl = _categoryImages[displayName];

                return Card(
                  color: card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white12, width: 0.8),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (c.name == 'Baby Items') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const BabyItemsSubcategoriesScreen(),
                          ),
                        );
                        return;
                      }
                      if (c.sections.length == 1) {
                        final section = c.sections.first;
                        _openProductTypes(section.productTypes, c.name);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SectionsScreen(category: c),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF262626),
                            ),
                            child: ClipOval(
                              child: imageUrl != null
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 36,
                                        color: gold,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 36,
                                      color: gold,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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

  void _openProductTypes(List<AldiProductType> pts, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ProductTypesScreen(categoryName: categoryName, productTypes: pts),
      ),
    );
  }
}

class _SectionsScreen extends StatelessWidget {
  final AldiCategory category;
  const _SectionsScreen({required this.category});
  static const bg = Color(0xFF1f1f1f);
  static const card = Color(0xFF181818);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: StoreAppBar(title: category.name),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: category.sections.length,
          itemBuilder: (_, i) {
            final s = category.sections[i];
            return Card(
              color: card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white12, width: 0.8),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ProductTypesScreen(
                      categoryName: category.name,
                      section: s.name,
                      productTypes: s.productTypes,
                    ),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      s.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
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

class _ProductTypesScreen extends StatelessWidget {
  final String categoryName;
  final String? section;
  final List<AldiProductType> productTypes;
  const _ProductTypesScreen({
    required this.categoryName,
    this.section,
    required this.productTypes,
  });
  static const bg = Color(0xFF1f1f1f);
  static const card = Color(0xFF181818);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: StoreAppBar(title: section ?? categoryName),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: productTypes.length,
          itemBuilder: (_, i) {
            final pt = productTypes[i];
            return Card(
              color: card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white12, width: 0.8),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => product_list.ProductListScreen(
                      category: categoryName,
                      subCategory: pt.name,
                      fileOverrides: [pt.filePath],
                      title: pt.name,
                    ),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      pt.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
