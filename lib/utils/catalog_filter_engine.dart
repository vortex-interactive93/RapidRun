// File: lib/utils/catalog_filter_engine.dart

import '../models/product.dart';
import 'bbw_taxonomy.dart';

enum SortOption {
  featured,
  priceLowToHigh,
  priceHighToLow,
  onSaleOnly,
}

class CatalogFilterEngine {
  /// Returns the exact filter chips using the single source of truth
  static List<String> getFilterChips({
    required String department,
    String? subcategory,
  }) {
    if (subcategory != null && subcategory.isNotEmpty) {
      final subChips = BbwTaxonomy.getChipsForDepartment(subcategory);
      if (subChips.length > 1) return subChips;
    }
    return BbwTaxonomy.getChipsForDepartment(department);
  }

  /// Backward-compatibility alias
  static List<String> getFilterChipsForDepartment(String department) {
    return BbwTaxonomy.getChipsForDepartment(department);
  }

  /// Evaluates whether a product matches the selected filter chip
  static bool matchesFilter({
    required Product product,
    required String activeChip,
    required String departmentName,
  }) {
    if (activeChip == 'All' || activeChip == 'All Products' || activeChip.isEmpty) return true;

    // 1. Check if the product already has the canonical tag
    if (product.tags.contains(activeChip)) return true;

    // 2. Dynamic evaluation against the taxonomy spec as a fallback
    final dept = BbwDepartment.fromString(departmentName);
    if (dept != null && BbwTaxonomy.registry.containsKey(dept)) {
      final specs = BbwTaxonomy.registry[dept]!;
      for (final spec in specs) {
        if (spec.label == activeChip) {
          return spec.matches(product);
        }
      }
    }

    // 3. Case-insensitive exact name/type matching
    final chipLower = activeChip.toLowerCase();
    final nameLower = product.name.toLowerCase();
    final typeLower = (product.productType ?? '').toLowerCase();

    return nameLower.contains(chipLower) || typeLower.contains(chipLower);
  }

  /// Applies search, chip filtering, and sorting to a list of products
  static List<Product> filterAndSort({
    required List<Product> products,
    required String activeChip,
    required String departmentName,
    String searchQuery = '',
    SortOption sort = SortOption.featured,
  }) {
    final cleanQuery = searchQuery.trim().toLowerCase();

    var filtered = products.where((product) {
      // Search filter
      if (cleanQuery.isNotEmpty) {
        final nameMatch = product.name.toLowerCase().contains(cleanQuery);
        final notesMatch = product.fragranceNotes.any((n) => n.toLowerCase().contains(cleanQuery));
        if (!nameMatch && !notesMatch) return false;
      }

      // Department/Chip filter
      return matchesFilter(
        product: product,
        activeChip: activeChip,
        departmentName: departmentName,
      );
    }).toList();

    // Deduplicate by Product Name + Unit to prevent duplicate cards
    final Map<String, Product> uniqueMap = {};
    for (final p in filtered) {
      final key = '${p.name.toLowerCase()}_${(p.unitShort ?? p.unit ?? '').toLowerCase()}';
      if (!uniqueMap.containsKey(key) && !uniqueMap.containsKey(p.id)) {
        uniqueMap[key] = p;
      }
    }
    filtered = uniqueMap.values.toList();

    // Sorting
    switch (sort) {
      case SortOption.priceLowToHigh:
        filtered.sort((a, b) => (a.price ?? 0.0).compareTo(b.price ?? 0.0));
        break;
      case SortOption.priceHighToLow:
        filtered.sort((a, b) => (b.price ?? 0.0).compareTo(a.price ?? 0.0));
        break;
      case SortOption.onSaleOnly:
        filtered = filtered.where((p) => p.hasSpecial || (p.promoBadge ?? '').isNotEmpty).toList();
        break;
      case SortOption.featured:
      default:
        break;
    }

    return filtered;
  }

  /// Legacy helper alias
  static List<Product> filterProducts({
    required List<Product> products,
    required String activeDepartment,
    String? activeSubcategory,
    required String selectedChip,
    String searchQuery = '',
    SortOption sortOption = SortOption.featured,
  }) {
    return filterAndSort(
      products: products,
      activeChip: selectedChip,
      departmentName: activeSubcategory ?? activeDepartment,
      searchQuery: searchQuery,
      sort: sortOption,
    );
  }

  /// Legacy predicate tester
  static bool matchesSubcategoryPredicate(Product p, String chip) {
    return matchesFilter(product: p, activeChip: chip, departmentName: 'Body Care');
  }
}
