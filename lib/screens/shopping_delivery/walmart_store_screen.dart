import 'package:flutter/material.dart';
import 'package:rapidrun/data/walmart_category_model.dart';
import 'package:rapidrun/screens/product_list_screen.dart' as product_list;
import '../../widgets/store_app_bar.dart';

class WalmartStoreScreen extends StatefulWidget {
  const WalmartStoreScreen({Key? key}) : super(key: key);
  @override
  State<WalmartStoreScreen> createState() => _WalmartStoreScreenState();
}

class _WalmartStoreScreenState extends State<WalmartStoreScreen> {
  late Future<WalmartCategoryData> _future;
  @override
  void initState() {
    super.initState();
    _future = WalmartCategoryData.load();
  }

  static const gold = Color(0xFFE6B450);
  static const bg = Color(0xFF1f1f1f);
  static const card = Color(0xFF181818);
  // Basic category icon mapping (extend as more categories added)
  static const Map<String, IconData> _categoryIcons = {
    'Grocery': Icons.local_grocery_store,
    'Personal Care': Icons.person,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: const StoreAppBar(title: 'Walmart Store'),
      body: FutureBuilder<WalmartCategoryData>(
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
                childAspectRatio: 1,
              ),
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final c = cats[i];
                final icon = _categoryIcons[c.name] ?? Icons.category;
                return Card(
                  color: card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (c.sections.length == 1) {
                        final section = c.sections.first;
                        _openProductTypes(section.productTypes, c.name);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _WalmartSectionsScreen(category: c),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 50, color: gold),
                          const SizedBox(height: 12),
                          Text(
                            c.name,
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
          );
        },
      ),
    );
  }

  void _openProductTypes(
    List<WalmartProductType> pts,
    String categoryName, {
    String? section,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WalmartProductTypesScreen(
          categoryName: categoryName,
          section: section,
          productTypes: pts,
        ),
      ),
    );
  }
}

class _WalmartSectionsScreen extends StatelessWidget {
  final WalmartCategory category;
  const _WalmartSectionsScreen({required this.category});
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
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _WalmartProductTypesScreen(
                      categoryName: category.name,
                      section: s.name,
                      productTypes: s.productTypes,
                    ),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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

class _WalmartProductTypesScreen extends StatelessWidget {
  final String categoryName;
  final String? section;
  final List<WalmartProductType> productTypes;
  const _WalmartProductTypesScreen({
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
              ),
              child: InkWell(
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
