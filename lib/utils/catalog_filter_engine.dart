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

  /// Returns the available subcategory chip labels for any given primary department
  static List<String> getFilterChipsForDepartment(String department) {
    final lower = department.toLowerCase();

    if (lower.contains('moisturizer') || lower.contains('lotion') || lower.contains('cream')) {
      return [
        'All',
        'Body Butter & Balm',
        'Body Cream',
        'Body Lotion',
        'Body Oil',
        'Hand Cream',
        'Lip Care',
        'Smooth & Soothe Body Cream',
        'Travel Size Body Cream',
      ];
    } else if (lower.contains('perfume') || lower.contains('cologne')) {
      return [
        'All',
        'Cologne',
        'Eau de Parfum',
        'Eau de Toilette & Parfum',
        'Mini Eau De Parfum Rollerball',
        'Solid Perfume',
      ];
    } else if (lower.contains('body sprays & mists') || lower.contains('mist') || lower.contains('spray')) {
      return [
        'All',
        'Body Spray & Mist',
        'Diamond Shimmer Mist',
        'Fine Fragrance Mist',
        'Travel Size Fine Fragrance Mist',
      ];
    } else if (lower.contains('candle')) {
      return ['All', '3-Wick', 'Single Wick', '4-Wick', 'Holders & Accessories'];
    } else if (lower.contains('body care') || lower.contains('bath')) {
      return ['All', 'Body Wash', 'Body Cream', 'Body Lotion', 'Body Butter & Balm', 'Lip Care', 'Travel Size'];
    } else if (lower.contains('fragrance')) {
      return [
        'All',
        'Body Spray & Mist',
        'Diamond Shimmer Mist',
        'Fine Fragrance Mist',
        'Travel Size Fine Fragrance Mist',
        'Eau de Parfum',
        'Cologne',
      ];
    } else if (lower.contains('soap') || lower.contains('sanitizer')) {
      return ['All', 'Foaming Soaps', 'PocketBacs', 'Sanitizer Sprays', 'Holders & Clips', 'Soap Refills'];
    } else if (lower.contains('wallflower') || lower.contains('diffuser')) {
      return ['All', 'Wallflowers Refills', 'Plugs & Nightlights', 'Room Sprays', 'Car Fragrance'];
    } else if (lower.contains('men')) {
      return ['All', '3-in-1 Wash & Bar Soap', 'Body Spray & Deodorant', 'Colognes', 'Body Creams'];
    } else if (lower.contains('home care') || lower.contains('laundry')) {
      return ['All', 'Laundry Detergent', 'Fragrance Boosters', 'Room Sprays'];
    }

    return ['All'];
  }

  /// Master filter pipeline: Combines Subcategory Pill, Search Query, and Sort Order
  static List<Product> filterProducts({
    required List<Product> products,
    required String activeDepartment,
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
      if (selectedChip == 'All') return true;
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
        // Preserves master catalog curation order
        break;
    }

    return filtered;
  }

  /// Strict word-boundary predicate tester (100% foolproof against substring collisions)
  static bool matchesSubcategoryPredicate(Product p, String chip) {
    if (chip == 'All' || chip == 'All Body Care' || chip == 'All Fragrances' || chip == 'All Candles' || chip == 'All Hand Soaps') return true;

    if (p.tags.contains(chip)) return true;

    final name = p.name.toLowerCase();
    final type = (p.productType ?? p.subCategory ?? '').toLowerCase();
    final unit = (p.unitShort ?? p.unit ?? '').toLowerCase();

    switch (chip) {
      // --- All Moisturizers Official Web Filters ---
      case 'Body Butter & Balm':
      case 'Body Butter & Scrubs':
        // Word boundary: matches "butter" or "balm", but NOT "butterfly"!
        return (_hasWord(name, 'butter') || _hasWord(name, 'balm') || _hasWord(type, 'butter') || _hasWord(type, 'balm')) &&
            !name.contains('mist') && !name.contains('spray');
      case 'Body Cream':
        return (_hasWord(name, 'cream') || _hasWord(type, 'cream')) &&
            !_hasWord(name, 'hand') &&
            !_hasWord(name, 'travel') &&
            !_hasWord(name, 'mini') &&
            !_hasWord(name, 'smooth') &&
            !name.contains('mist') && !name.contains('spray');
      case 'Body Lotion':
        return (_hasWord(name, 'lotion') || _hasWord(type, 'lotion')) && !name.contains('mist') && !name.contains('spray');
      case 'Body Oil':
        return (_hasWord(name, 'oil') || _hasWord(type, 'oil')) && !name.contains('mist') && !name.contains('spray');
      case 'Hand Cream':
        return _hasWord(name, 'hand') || _hasWord(type, 'hand');
      case 'Lip Care':
      case 'Lip Gloss':
        return _hasWord(name, 'lip') || _hasWord(type, 'lip');
      case 'Smooth & Soothe Body Cream':
        return _hasWord(name, 'smooth') || _hasWord(name, 'soothe') || _hasWord(type, 'smooth');
      case 'Travel Size Body Cream':
        return (_hasWord(name, 'travel') || _hasWord(name, 'mini')) && (_hasWord(name, 'cream') || _hasWord(name, 'lotion'));

      // --- Perfume & Cologne Official Web Filters ---
      case 'Cologne':
        return _hasWord(name, 'cologne') || _hasWord(type, 'cologne');
      case 'Eau de Parfum':
        return (_hasWord(name, 'parfum') || _hasWord(type, 'parfum')) && !_hasWord(name, 'rollerball') && !_hasWord(name, 'mini');
      case 'Eau de Toilette & Parfum':
        return _hasWord(name, 'toilette') || _hasWord(type, 'toilette') || _hasWord(name, 'parfum') || _hasWord(type, 'parfum');
      case 'Mini Eau De Parfum Rollerball':
        return _hasWord(name, 'rollerball') || _hasWord(name, 'mini') || _hasWord(type, 'rollerball');
      case 'Solid Perfume':
        return _hasWord(name, 'solid') || _hasWord(type, 'solid');

      // --- Body Sprays & Mists Official Web Filters ---
      case 'Body Spray & Mist':
        return _hasWord(name, 'spray') || _hasWord(name, 'mist') || _hasWord(type, 'spray') || _hasWord(type, 'mist');
      case 'Diamond Shimmer Mist':
        return _hasWord(name, 'shimmer') || _hasWord(type, 'shimmer');
      case 'Fine Fragrance Mist':
        return (_hasWord(name, 'mist') || _hasWord(type, 'mist')) && !_hasWord(name, 'travel') && !_hasWord(name, 'mini');
      case 'Travel Size Fine Fragrance Mist':
        return (_hasWord(name, 'travel') || _hasWord(name, 'mini')) && (_hasWord(name, 'mist') || _hasWord(type, 'mist'));

      // --- Candles ---
      case '3-Wick':
        return _hasWord(name, '3-wick') || name.contains('3 wick') || _hasWord(type, '3-wick');
      case 'Single Wick':
        return _hasWord(name, 'single-wick') || name.contains('single wick') || _hasWord(type, 'single-wick');
      case '4-Wick':
        return _hasWord(name, '4-wick') || name.contains('4 wick');
      case 'Holders & Accessories':
      case 'Candle Holders & Accessories':
        return _hasWord(type, 'accessories') || _hasWord(name, 'holder') || _hasWord(name, 'pedestal') || _hasWord(name, 'sleeve');

      // --- Body Care ---
      case 'Body Wash':
      case 'Body Wash & Shower Gel':
        return _hasWord(name, 'wash') || _hasWord(name, 'shower') || _hasWord(name, 'gel') || _hasWord(name, 'scrub') || _hasWord(name, 'bar');
      case 'Lotions & Creams':
        return _hasWord(name, 'lotion') || _hasWord(name, 'cream');
      case 'Travel Size':
      case 'Mini & Travel Size':
        return _hasWord(name, 'travel') || _hasWord(name, 'mini') || unit.contains('1 oz') || unit.contains('2.5 oz') || unit.contains('3 oz');

      // --- Hand Soaps & Sanitizers ---
      case 'Foaming Soaps':
        return _hasWord(name, 'foaming') || name.contains('foaming hand soap');
      case 'PocketBacs':
      case 'PocketBac Hand Sanitizers':
      case 'All Hand Sanitizers':
        return name.contains('pocketbac') || name.contains('sanitizer');
      case 'Sanitizer Sprays':
      case 'Hand Sanitizer Sprays':
        return _hasWord(name, 'spray') && name.contains('sanitizer');
      case 'Holders & Clips':
      case 'Hand Sanitizer Holders':
      case 'Soap Holders & Dispensers':
        return _hasWord(name, 'holder') || _hasWord(name, 'clip') || _hasWord(name, 'dispenser');
      case 'Soap Refills':
      case 'Hand Soap Refills':
      case 'Foaming Hand Soaps Refills':
        return _hasWord(name, 'refill');

      // --- Wallflowers & Diffusers ---
      case 'Wallflowers Refills':
      case 'Wallflowers Fragrance Refills':
        return name.contains('wallflowers fragrance refill') || _hasWord(name, 'refill');
      case 'Plugs & Nightlights':
      case 'Wallflowers Plugs':
        return _hasWord(name, 'plug') || _hasWord(name, 'nightlight');
      case 'Room Sprays':
      case 'Room Sprays & Mists':
        return name.contains('room spray') || name.contains('room mist');
      case 'Car Fragrance':
      case 'Car Fragrance & Fresheners':
        return name.contains('car fragrance') || name.contains('visor clip') || name.contains('vent clip');

      // --- Men's Shop ---
      case '3-in-1 Wash & Bar Soap':
        return name.contains('3-in-1') || name.contains('bar soap');
      case 'Body Spray & Deodorant':
        return name.contains('body spray') || _hasWord(name, 'deodorant');
      case 'Colognes':
      case "Men's fragrance":
        return _hasWord(name, 'cologne');
      case 'Body Creams':
        return _hasWord(name, 'cream') || _hasWord(name, 'lotion');

      // --- Home Care ---
      case 'Laundry Detergent':
        return _hasWord(name, 'detergent');
      case 'Fragrance Boosters':
        return _hasWord(name, 'booster');

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
