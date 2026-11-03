import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:rapidrun/screens/product_list_screen.dart' as product_list;
import '../../widgets/store_app_bar.dart';
import '../search/store_search_screen.dart';

abstract class StoreCategoryModel {
  String get name;
  List<StoreSectionModel> get sections;
  int? get iconCodePoint;
}

abstract class StoreSectionModel {
  String get name;
  List<StoreProductTypeModel> get productTypes;
}

abstract class StoreProductTypeModel {
  String get name;
  String get filePath;
  int? get iconCodePoint;
}

class GenericStoreScreen<T extends StoreCategoryModel> extends StatelessWidget {
  final Future<List<T>> categoriesFuture;
  final String title;
  final Map<String, IconData>? categoryIcons;
  final bool Function(T category)? interceptCategoryTap;
  final Color gold;
  final Color background;
  final Color card;

  const GenericStoreScreen({
    super.key,
    required this.categoriesFuture,
    required this.title,
    this.categoryIcons,
    this.interceptCategoryTap,
    this.gold = const Color(0xFFE6B450),
    this.background = const Color(0xFF1f1f1f),
    this.card = const Color(0xFF181818),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: StoreAppBar(
        title: title,
        showSearch: true,
        onSearch: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _SearchSheet(store: title),
          );
        },
      ),
      body: FutureBuilder<List<T>>(
        future: categoriesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: gold));
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          final cats = snap.data ?? const [];
          if (cats.isEmpty) {
            return const Center(
              child: Text(
                'No categories found.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
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
                final icon = _resolveIcon(c);
                return Card(
                  color: card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (interceptCategoryTap?.call(c) == true) return;
                      if (c.sections.length == 1) {
                        final section = c.sections.first;
                        _openProductTypes(
                          context,
                          c.name,
                          section.productTypes,
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SectionsScreen(
                              category: c,
                              gold: gold,
                              background: background,
                              card: card,
                            ),
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

  IconData _resolveIcon(StoreCategoryModel c) {
    if (c.iconCodePoint != null) {
      return IconData(c.iconCodePoint!, fontFamily: 'MaterialIcons');
    }
    final mapped = categoryIcons?[c.name];
    return mapped ?? Icons.category;
  }

  void _openProductTypes(
    BuildContext context,
    String categoryName,
    List<StoreProductTypeModel> pts, {
    String? section,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProductTypesScreen(
          categoryName: categoryName,
          section: section,
          productTypes: pts,
          gold: gold,
          background: background,
          card: card,
        ),
      ),
    );
  }
}

class _SearchSheet extends StatelessWidget {
  final String store;
  const _SearchSheet({required this.store});
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E1E1E).withValues(alpha: 0.85),
                    const Color(0xFF121212).withValues(alpha: 0.90),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 28,
                    offset: const Offset(0, -6),
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: StoreSearchScreen(store: store)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionsScreen extends StatelessWidget {
  final StoreCategoryModel category;
  final Color gold;
  final Color background;
  final Color card;
  const _SectionsScreen({
    required this.category,
    required this.gold,
    required this.background,
    required this.card,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ProductTypesScreen(
                      categoryName: category.name,
                      section: s.name,
                      productTypes: s.productTypes,
                      gold: gold,
                      background: background,
                      card: card,
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
  final List<StoreProductTypeModel> productTypes;
  final Color gold;
  final Color background;
  final Color card;
  const _ProductTypesScreen({
    required this.categoryName,
    this.section,
    required this.productTypes,
    required this.gold,
    required this.background,
    required this.card,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
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
