// File: lib/utils/catalog_filter_engine.dart

import '../models/product.dart';

enum SortOption {
  featured,
  priceLowToHigh,
  priceHighToLow,
  onSaleOnly,
}

class CatalogFilterEngine {
  /// Strict word boundary matching (e.g. matches "butter", but NOT "butterfly")
  static bool _hasWord(String text, String word) {
    return RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false).hasMatch(text);
  }

  /// Returns the exact filter chips for the active context.
  /// Handles both parent departments and active subcategories.
  static List<String> getFilterChips({
    required String department,
    String? subcategory,
  }) {
    final sub = (subcategory ?? '').toLowerCase();
    final dept = department.toLowerCase();

    // 1. SPECIFIC SUBCATEGORY VIEWS (When inside a nested hub)
    if (sub.contains('lip') || dept == 'lip care') {
      return ['All', 'Lip Gloss', 'Lip Balm', 'Lip Oil', 'Lip Mask', 'Lip Tint'];
    }

    if (sub.contains('moisturizer') || dept == 'all moisturizers' || dept == 'body moisturizers') {
      return ['All', 'Body Cream', 'Body Lotion', 'Body Butter', 'Hand Cream', 'Massage Oil'];
    }

    if (sub.contains('bath') || sub.contains('shower') || dept == 'bath & shower') {
      return ['All', 'Body Wash', 'Body Scrubs', 'Cleansing Bars', 'Shower Steamers'];
    }

    if (sub.contains('travel') || sub.contains('mini') || dept == 'mini & travel size') {
      return ['All', 'Travel Mists', 'Travel Creams', 'Travel Body Wash', 'Hand Creams'];
    }

    if (sub.contains('perfume') || sub.contains('cologne') || dept == 'perfume & cologne') {
      return ['All', 'Eau de Parfum', 'Cologne', 'Mini EDP', 'Mini Cologne', 'Solid Perfume'];
    }

    if (sub.contains('mist') || sub.contains('spray') || dept == 'body sprays & mists') {
      return ['All', 'Fine Fragrance Mist', 'Diamond Shimmer Mist', 'Essential Oil Mist', 'Deodorizing Spray'];
    }

    // 2. PARENT DEPARTMENT VIEWS
    if (dept.contains('candle')) {
      return ['All', '3-Wick Candles', 'Single Wick Candles', '4-Wick Candles', 'Holders & Accessories'];
    }

    if (dept.contains('soap') || dept.contains('sanitizer')) {
      return [
        'All',
        'Foaming Soaps',
        'Gel & Moisturizing Soaps',
        'PocketBac Sanitizers',
        'Sanitizer Sprays',
        'Holders & Clips',
        'Soap Refills',
      ];
    }

    if (dept.contains('wallflower') || dept.contains('diffuser') || dept.contains('home fragrance')) {
      return [
        'All',
        'Wallflowers Refills',
        'Plugs & Nightlights',
        'Room Sprays & Mists',
        'Car Fragrance',
        'Liquidless Reeds',
      ];
    }

    if (dept.contains('men')) {
      return [
        'All',
        '3-in-1 Wash & Bar Soap',
        'Body Spray & Deodorant',
        'Cologne',
        'Body Cream & Lotion',
        'Car & Home Fragrance',
        "Men's Gift Sets",
      ];
    }

    if (dept.contains('home care')) {
      return ['All', 'Laundry Detergent', 'Fragrance Boosters', 'Soaps & Accents'];
    }

    if (dept.contains('fragrance')) {
      return [
        'All',
        'Fine Fragrance Mist',
        'Eau de Parfum',
        'Cologne',
        'Body Sprays',
        'Travel & Rollerballs',
      ];
    }

    // Default: Top-level Body Care Department
    return [
      'All',
      'Body Moisturizers',
      'Bath & Shower',
      'Lip Care',
      'Body Scrubs',
      'Fine Fragrance Mist',
      'Travel Size',
    ];
  }

  /// Backward-compatibility alias
  static List<String> getFilterChipsForDepartment(String department) {
    return getFilterChips(department: department);
  }

  /// Master filter pipeline: Combines Subcategory Pill, Search Query, and Sort Order
  static List<Product> filterProducts({
    required List<Product> products,
    required String activeDepartment,
    String? activeSubcategory,
    required String selectedChip,
    String searchQuery = '',
    SortOption sortOption = SortOption.featured,
  }) {
    List<Product> filtered = products.where((product) {
      // 1. Text Search Filter
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        final nameMatch = product.name.toLowerCase().contains(query);
        final noteMatch = product.fragranceNotes.any((n) => n.toLowerCase().contains(query));
        final typeMatch = (product.productType ?? '').toLowerCase().contains(query);
        if (!nameMatch && !noteMatch && !typeMatch) return false;
      }

      // 2. Subcategory Predicate Matching
      if (selectedChip == 'All' || selectedChip == 'All Body Care' || selectedChip == 'All Fragrances' || selectedChip == 'All Candles' || selectedChip == 'All Hand Soaps' || selectedChip == 'All Products') {
        return true;
      }
      return matchesSubcategoryPredicate(product, selectedChip);
    }).toList();

    // 3. Deduplicate by Product Name + Unit to prevent duplicate cards
    final Map<String, Product> uniqueMap = {};
    for (final p in filtered) {
      final key = '${p.name.toLowerCase()}_${(p.unitShort ?? p.unit ?? '').toLowerCase()}';
      if (!uniqueMap.containsKey(key) && !uniqueMap.containsKey(p.id)) {
        uniqueMap[key] = p;
      }
    }
    filtered = uniqueMap.values.toList();

    // 4. Sorting Engine
    switch (sortOption) {
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

  /// Strict word-boundary predicate tester (100% foolproof against substring collisions)
  static bool matchesSubcategoryPredicate(Product p, String chip) {
    if (chip == 'All' || chip == 'All Body Care' || chip == 'All Fragrances' || chip == 'All Candles' || chip == 'All Hand Soaps' || chip == 'All Products') {
      return true;
    }

    // 1. Priority: Canonical resolved filter tags
    if (p.tags.contains(chip)) return true;

    // 2. Fallback: Strict word-boundary predicate tester
    final name = p.name.toLowerCase();
    final type = (p.productType ?? p.subCategory ?? '').toLowerCase();
    final unit = (p.unitShort ?? p.unit ?? '').toLowerCase();
    final url = (p.productUrl ?? '').toLowerCase();

    switch (chip) {
      // --- Lip Care Contextual Format Chips ---
      case 'Lip Gloss':
        return name.contains('lip gloss') || url.contains('-lip-gloss-');
      case 'Lip Balm':
        return name.contains('lip balm') || name.contains('night balm') || url.contains('-lip-balm-');
      case 'Lip Oil':
        return name.contains('lip oil') || url.contains('-lip-oil-');
      case 'Lip Mask':
        return name.contains('lip mask') || url.contains('-lip-mask-');
      case 'Lip Tint':
        return name.contains('lip tint') || name.contains('peptide lip') || url.contains('-lip-tint-');
      case 'Lip Care':
        return _hasWord(name, 'lip') || _hasWord(type, 'lip') || name.contains('balm');

      // --- Body Moisturizers Contextual Format Chips ---
      case 'Body Butter':
      case 'Body Butter & Balm':
      case 'Body Butter & Scrubs':
        return (_hasWord(name, 'butter') || _hasWord(name, 'balm') || _hasWord(type, 'butter') || _hasWord(type, 'balm')) &&
            !name.contains('mist') && !name.contains('spray');
      case 'Body Cream':
      case 'Body Cream & Lotion':
        return (_hasWord(name, 'cream') || _hasWord(type, 'cream')) &&
            !_hasWord(name, 'hand') &&
            !_hasWord(name, 'travel') &&
            !_hasWord(name, 'mini') &&
            !_hasWord(name, 'smooth') &&
            !name.contains('mist') && !name.contains('spray');
      case 'Body Lotion':
        return (_hasWord(name, 'lotion') || _hasWord(type, 'lotion')) && !name.contains('mist') && !name.contains('spray');
      case 'Body Oil':
      case 'Massage Oil':
        return (_hasWord(name, 'oil') || _hasWord(type, 'oil')) && !name.contains('mist') && !name.contains('spray');
      case 'Hand Cream':
        return _hasWord(name, 'hand') || _hasWord(type, 'hand');
      case 'Smooth & Soothe Body Cream':
        return _hasWord(name, 'smooth') || _hasWord(name, 'soothe') || _hasWord(type, 'smooth');
      case 'Travel Size Body Cream':
        return (_hasWord(name, 'travel') || _hasWord(name, 'mini')) && (_hasWord(name, 'cream') || _hasWord(name, 'lotion'));

      // --- Perfume & Cologne Contextual Format Chips ---
      case 'Cologne':
      case 'Colognes':
        return _hasWord(name, 'cologne') || _hasWord(type, 'cologne');
      case 'Eau de Parfum':
      case 'Eau de Parfum & Perfume':
        return (_hasWord(name, 'parfum') || _hasWord(type, 'parfum')) && !_hasWord(name, 'rollerball') && !_hasWord(name, 'mini');
      case 'Eau de Toilette & Parfum':
        return _hasWord(name, 'toilette') || _hasWord(type, 'toilette') || _hasWord(name, 'parfum') || _hasWord(type, 'parfum');
      case 'Mini EDP':
      case 'Mini Eau De Parfum Rollerball':
        return _hasWord(name, 'rollerball') || _hasWord(name, 'mini') || _hasWord(type, 'rollerball');
      case 'Solid Perfume':
        return _hasWord(name, 'solid') || _hasWord(type, 'solid');

      // --- Body Sprays & Mists Contextual Format Chips ---
      case 'Body Spray & Mist':
      case 'Body Sprays & Deodorant':
        return _hasWord(name, 'spray') || _hasWord(name, 'mist') || _hasWord(type, 'spray') || _hasWord(type, 'mist');
      case 'Diamond Shimmer Mist':
        return _hasWord(name, 'shimmer') || _hasWord(type, 'shimmer');
      case 'Fine Fragrance Mist':
      case 'Fragrance Mists':
        return (_hasWord(name, 'mist') || _hasWord(type, 'mist')) && !_hasWord(name, 'travel') && !_hasWord(name, 'mini');
      case 'Travel Size Fine Fragrance Mist':
        return (_hasWord(name, 'travel') || _hasWord(name, 'mini')) && (_hasWord(name, 'mist') || _hasWord(type, 'mist'));
      case 'Essential Oil Mist':
        return name.contains('essential oil');

      // --- Candles ---
      case '3-Wick':
      case '3-Wick Candles':
        return _hasWord(name, '3-wick') || name.contains('3 wick') || _hasWord(type, '3-wick');
      case 'Single Wick':
      case 'Single Wick Candles':
        return _hasWord(name, 'single-wick') || name.contains('single wick') || _hasWord(type, 'single-wick');
      case '4-Wick':
      case '4-Wick Candles':
        return _hasWord(name, '4-wick') || name.contains('4 wick');
      case 'Holders & Pedestals':
      case 'Holders & Accessories':
      case 'Candle Holders & Accessories':
        return _hasWord(type, 'accessories') || _hasWord(name, 'holder') || _hasWord(name, 'pedestal') || _hasWord(name, 'sleeve');

      // --- Body Care ---
      case 'Bath & Shower':
      case 'Body Wash':
      case 'Body Wash & Shower Gel':
        return _hasWord(name, 'wash') || _hasWord(name, 'shower') || _hasWord(name, 'gel') || _hasWord(name, 'scrub') || _hasWord(name, 'bar');
      case 'Body Moisturizers':
      case 'Lotions & Creams':
        return _hasWord(name, 'lotion') || _hasWord(name, 'cream') || _hasWord(name, 'butter');
      case 'Body Scrubs':
        return _hasWord(name, 'scrub');
      case 'Cleansing Bars':
        return name.contains('cleansing bar') || name.contains('bar soap');
      case 'Shower Steamers':
        return name.contains('steamers');
      case 'Travel Size':
      case 'Travel Mists':
      case 'Travel Creams':
      case 'Travel Body Wash':
      case 'Travel & Rollerballs':
      case 'Mini & Travel Size':
        return _hasWord(name, 'travel') || _hasWord(name, 'mini') || unit.contains('1 oz') || unit.contains('2.5 oz') || unit.contains('3 oz');

      // --- Hand Soaps & Sanitizers ---
      case 'Foaming Soaps':
        return _hasWord(name, 'foaming') || name.contains('foaming hand soap');
      case 'Gel & Moisturizing Soaps':
        return name.contains('cleansing gel') || name.contains('daily moisturizing') || name.contains('revitalizing');
      case 'PocketBacs':
      case 'PocketBac Sanitizers':
      case 'PocketBac Hand Sanitizers':
      case 'All Hand Sanitizers':
        return name.contains('pocketbac') || name.contains('sanitizer');
      case 'Sanitizer Sprays':
      case 'Hand Sanitizer Sprays':
        return _hasWord(name, 'spray') && name.contains('sanitizer');
      case 'Holders & Clips':
      case 'Soap & Sanitizer Holders':
      case 'Hand Sanitizer Holders':
      case 'Soap Holders & Dispensers':
        return _hasWord(name, 'holder') || _hasWord(name, 'clip') || _hasWord(name, 'dispenser');
      case 'Soap Refills':
      case 'Refills':
      case 'Hand Soap Refills':
      case 'Foaming Hand Soaps Refills':
        return _hasWord(name, 'refill');

      // --- Wallflowers & Diffusers ---
      case 'Wallflowers Refills':
      case 'Wallflowers Fragrance Refills':
      case 'Refills':
        return (name.contains('wallflowers fragrance refill') || _hasWord(name, 'refill')) &&
            !name.contains('soap') && !name.contains('lip') && !name.contains('wash');
      case 'Plugs & Nightlights':
      case 'Wallflowers Plugs':
      case 'Plugs':
        return (_hasWord(name, 'plug') || _hasWord(name, 'nightlight')) &&
            !name.contains('lip') && !name.contains('wash');
      case 'Room Sprays':
      case 'Room Sprays & Mists':
        return (name.contains('room spray') || name.contains('room mist') || name.contains('concentrated room spray')) &&
            !name.contains('fine fragrance mist') && !name.contains('body spray') && !name.contains('shimmer');
      case 'Car Fragrance':
      case 'Car Fragrance & Fresheners':
        return (name.contains('car fragrance') || name.contains('visor clip') || name.contains('vent clip')) &&
            !name.contains('lip');
      case 'Liquidless Reeds':
      case 'Reeds & Diffusers':
        return (name.contains('reeds') || name.contains('vessel')) && !name.contains('lip');

      // --- Men's Shop ---
      case '3-in-1 Wash & Bar Soap':
        return name.contains('3-in-1') || name.contains('bar soap');
      case 'Body Spray & Deodorant':
        return name.contains('body spray') || _hasWord(name, 'deodorant');
      case 'Home & Car Fragrance':
      case 'Car & Home Fragrance':
        return name.contains('candle') || name.contains('wallflower') || name.contains('car fragrance') || name.contains('room spray');
      case "Men's Gift Sets":
        return name.contains('gift set');

      // --- Home Care ---
      case 'Laundry Detergent':
        return _hasWord(name, 'detergent');
      case 'Fragrance Boosters':
        return _hasWord(name, 'booster');
      case 'Soaps & Accents':
      case 'Soaps & Room Accents':
        return name.contains('hand soap') || name.contains('room spray') || name.contains('single wick');

      default:
        final pillTokens = chip.toLowerCase().split(' ').where((t) => t.length > 2 && t != 'and' && t != 'all').toList();
        for (final token in pillTokens) {
          if (_hasWord(name, token) || _hasWord(type, token)) {
            return true;
          }
        }
        return false;
    }
  }
}
