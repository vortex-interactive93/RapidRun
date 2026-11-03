import 'package:flutter/material.dart';
import 'package:rapidrun/screens/product_list_screen.dart' as global_products;

class BabyItemsSubcategoriesScreen extends StatelessWidget {
  const BabyItemsSubcategoriesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const subcategories = [
      {'name': 'Baby Food & Snacks', 'icon': Icons.fastfood},
      {'name': 'Diapers, Wipes, & Wash', 'icon': Icons.baby_changing_station},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1f1f1f),
      appBar: AppBar(
        title: const Text(
          'Baby Items Subcategories',
          style: TextStyle(color: gold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF181818),
        iconTheme: const IconThemeData(color: gold),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: subcategories.length,
          itemBuilder: (context, index) {
            final subcategory = subcategories[index];
            return Card(
              color: const Color(0xFF181818),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => global_products.ProductListScreen(
                        category: 'Baby Items',
                        subCategory: subcategory['name'] as String,
                        // For now only Baby Food & Snacks has a dedicated file; others fall back to mapping.
                        fileOverrides:
                            subcategory['name'] == 'Baby Food & Snacks'
                            ? const [
                                'assets/stores/aldi/aldi_baby_food_snacks.json',
                              ]
                            : null,
                        title: subcategory['name'] as String,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        subcategory['icon'] as IconData,
                        size: 50,
                        color: gold,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subcategory['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
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
