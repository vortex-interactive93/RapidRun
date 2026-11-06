// File: lib/utils/catalog_filter_engine.dart

import '../models/product.dart';

enum SortOption {
  featured,
  priceLowToHigh,
  priceHighToLow,
  onSaleOnly,
}

class CatalogFilterEngine {
  /// Returns the available subcategory chip labels for any given primary department
  static List<String> getFilterChipsForDepartment(String department) {
    final lower = department.toLowerCase();

    if (lower.contains('perfume') || lower.contains('cologne')) {
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
    } else if (lower.contains('body care') || lower.contains('moisturizer') || lower.contains('bath')) {
      return ['All', 'Body Wash', 'Lotions & Creams', 'Body Butter & Scrubs', 'Lip Care', 'Travel Size'];
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

    // 3. Sorting Engine
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

  /// Dynamic predicate tester (no fragile static strings!)
  static bool matchesSubcategoryPredicate(Product p, String chip) {
    if (chip == 'All') return true;

    final name = p.name.toLowerCase();
    final type = (p.productType ?? p.subCategory ?? '').toLowerCase();
    final unit = (p.unitShort ?? p.unit ?? '').toLowerCase();

    switch (chip) {
      // --- Perfume & Cologne Official Web Filters ---
      case 'Cologne':
        return type.contains('cologne') || name.contains('cologne');
      case 'Eau de Parfum':
        return type.contains('eau de parfum') || name.contains('eau de parfum') || (name.contains('parfum') && !name.contains('rollerball') && !name.contains('mini'));
      case 'Eau de Toilette & Parfum':
        return type.contains('toilette') || name.contains('toilette') || type.contains('parfum') || name.contains('parfum');
      case 'Mini Eau De Parfum Rollerball':
        return name.contains('rollerball') || name.contains('mini') || type.contains('rollerball') || type.contains('mini');
      case 'Solid Perfume':
        return name.contains('solid') || type.contains('solid');

      // --- Body Sprays & Mists Official Web Filters ---
      case 'Body Spray & Mist':
        return type.contains('body spray') || type.contains('mist') || name.contains('body spray') || name.contains('mist');
      case 'Diamond Shimmer Mist':
        return name.contains('shimmer') || type.contains('shimmer');
      case 'Fine Fragrance Mist':
        return (type.contains('fine fragrance mist') || name.contains('fine fragrance mist') || name.contains('fragrance mist')) && !name.contains('travel') && !name.contains('mini');
      case 'Travel Size Fine Fragrance Mist':
        return (name.contains('travel') || name.contains('mini') || type.contains('travel')) && (name.contains('mist') || type.contains('mist'));

      // --- Candles ---
      case '3-Wick':
        return name.contains('3-wick') || name.contains('3 wick') || type.contains('3-wick');
      case 'Single Wick':
        return name.contains('single wick') || name.contains('single-wick') || type.contains('single wick');
      case '4-Wick':
        return name.contains('4-wick') || name.contains('4 wick');
      case 'Holders & Accessories':
      case 'Candle Holders & Accessories':
        return type.contains('accessories') || name.contains('holder') || name.contains('pedestal') || name.contains('sleeve');

      // --- Body Care ---
      case 'Body Wash':
      case 'Body Wash & Shower Gel':
        return name.contains('body wash') || name.contains('shower gel') || name.contains('shower soap') || name.contains('foam bath') || type.contains('wash');
      case 'Lotions & Creams':
      case 'Body Cream':
      case 'Body Lotion':
        return name.contains('lotion') || name.contains('cream') || type.contains('lotion') || type.contains('cream');
      case 'Body Butter & Scrubs':
      case 'Body Butter & Balm':
      case 'Body Scrub':
        return name.contains('butter') || name.contains('scrub') || name.contains('balm') || name.contains('exfoliat');
      case 'Lip Care':
      case 'Lip Gloss':
        return name.contains('lip');
      case 'Travel Size':
      case 'Mini & Travel Size':
      case 'Travel Size Body Cream':
        return name.contains('travel') || name.contains('mini') || name.contains('rollerball') || unit.contains('1 oz') || unit.contains('2.5 oz') || unit.contains('0.23 oz') || unit.contains('3 oz');

      // --- Hand Soaps & Sanitizers ---
      case 'Foaming Soaps':
        return name.contains('foaming hand soap') || name.contains('cleansing gel') || name.contains('foaming');
      case 'PocketBacs':
      case 'PocketBac Hand Sanitizers':
      case 'All Hand Sanitizers':
        return name.contains('pocketbac') || name.contains('sanitizer');
      case 'Sanitizer Sprays':
      case 'Hand Sanitizer Sprays':
        return name.contains('spray') && name.contains('sanitizer');
      case 'Holders & Clips':
      case 'Hand Sanitizer Holders':
      case 'Soap Holders & Dispensers':
        return name.contains('holder') || name.contains('clip') || name.contains('wristlet') || name.contains('lanyard') || name.contains('dispenser');
      case 'Soap Refills':
      case 'Hand Soap Refills':
      case 'Foaming Hand Soaps Refills':
        return name.contains('refill');

      // --- Wallflowers & Diffusers ---
      case 'Wallflowers Refills':
      case 'Wallflowers Fragrance Refills':
        return name.contains('wallflowers fragrance refill') || name.contains('refill');
      case 'Plugs & Nightlights':
      case 'Wallflowers Plugs':
        return name.contains('plug') || name.contains('nightlight');
      case 'Room Sprays':
      case 'Room Sprays & Mists':
        return name.contains('room spray') || name.contains('room mist') || name.contains('concentrated room spray');
      case 'Car Fragrance':
      case 'Car Fragrance & Fresheners':
        return name.contains('car fragrance') || name.contains('visor clip') || name.contains('vent clip') || name.contains('diffuser');

      // --- Men's Shop ---
      case '3-in-1 Wash & Bar Soap':
        return name.contains('3-in-1') || name.contains('bar soap') || name.contains('cleansing bar');
      case 'Body Spray & Deodorant':
        return name.contains('body spray') || name.contains('deodorant') || name.contains('antiperspirant');
      case 'Colognes':
      case "Men's fragrance":
        return name.contains('cologne');
      case 'Body Creams':
        return name.contains('body cream') || name.contains('lotion');

      // --- Home Care ---
      case 'Laundry Detergent':
        return type.contains('detergent') || name.contains('detergent');
      case 'Fragrance Boosters':
        return type.contains('booster') || name.contains('booster');

      default:
        final pillTokens = chip.toLowerCase().split(' ').where((t) => t.length > 2 && t != 'and' && t != 'all').toList();
        for (final token in pillTokens) {
          if (name.contains(token) || type.contains(token)) {
            return true;
          }
        }
        return false;
    }
  }
}
