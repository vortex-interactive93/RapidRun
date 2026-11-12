// File: lib/services/bbw_boutique_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';

class BbwBoutiqueRepository {
  static final BbwBoutiqueRepository instance = BbwBoutiqueRepository._();
  BbwBoutiqueRepository._();

  /// Ordered from oldest/fallback to newest scraped files.
  /// Later files in this list ALWAYS overwrite older prices for the same SKU.
  static const List<String> _allAssetFiles = [
    // Legacy / base filenames (loaded first so newer scrapes overwrite them)
    'assets/data/candles.json',
    'assets/data/body_care.json',
    'assets/data/all_fragrance.json',
    'assets/data/hand_soaps_sanitizers.json',
    'assets/data/wallflowers_diffusers.json',
    'assets/data/mens_shop.json',
    'assets/data/home_care.json',
    // Latest scraped files (loaded last so their live prices always win)
    'assets/data/candles_2.json',
    'assets/data/candles_3.json',
    'assets/data/body_care_2.json',
    'assets/data/body_care_3.json',
    'assets/data/all_fragrance_3.json',
    'assets/data/all_fragrance_4.json',
    'assets/data/mini_and_travel_size.json',
    'assets/data/hand_soaps_sanitizers_2.json',
    'assets/data/hand_soaps_sanitizers_3.json',
    'assets/data/wallflowers_diffusers_2.json',
    'assets/data/wallflowers_diffusers_3.json',
    'assets/data/home_care_2.json',
    'assets/data/home_care_3.json',
    'assets/data/3_wick_candles.json',
    'assets/data/single_wick_candles.json',
    'assets/data/all_candles.json',
    'assets/data/all_moisturizers.json',
    'assets/data/bath_shower.json',
    'assets/data/Body_Sprays_Mists.json',
    'assets/data/Perfume_Cologne.json',
    'assets/data/mini_travel_size.json',
    'assets/data/all_hand_soaps.json',
    'assets/data/all_hand_sanitizers.json',
    'assets/data/all_wallflowers.json',
    'assets/data/room_sprays_mists.json',
    'assets/data/laundry_care.json',
    'assets/data/bbw_instore_catalog.json',
  ];

  static const List<String> _mensCoreScents = [
    'ocean',
    'bourbon',
    'noir',
    'graphite',
    'santal ridge',
    'after dark',
    'into orbit',
    'crafted cognac',
    'freshwater',
    'whiskey reserve',
    'football season',
    'lasting legacy',
    'vanilla noir',
  ];

  bool _isLoaded = false;
  final Map<String, List<Product>> _roomBuckets = {
    'candles': [],
    'body_care': [],
    'fragrance': [],
    'minis': [],
    'soaps': [],
    'wallflowers': [],
    'mens': [],
    'home_care': [],
  };

  List<Product> _allUniqueProducts = [];
  List<Product> get allUniqueProducts => _allUniqueProducts;

  /// Force-clears memory cache so a Hot Restart or manual reload re-reads JSONs cleanly.
  void resetCache() {
    _isLoaded = false;
    _allUniqueProducts = [];
    for (final key in _roomBuckets.keys) {
      _roomBuckets[key] = [];
    }
  }

  /// Loads, deduplicates by SKU, sanitizes HTML entities, normalizes units,
  /// and routes every product to its true canonical Boutique Room.
  Future<void> ensureInitialized({bool forceReload = false}) async {
    if (forceReload) resetCache();
    if (_isLoaded) return;

    final Map<String, Product> dedupedBySku = {};
    int filesLoadedCount = 0;

    for (final path in _allAssetFiles) {
      try {
        final rawString = await rootBundle.loadString(path);
        final List<dynamic> decoded = json.decode(rawString);
        filesLoadedCount++;

        for (final entry in decoded) {
          if (entry is! Map<String, dynamic>) continue;

          final normalizedMap = _normalizeRawProduct(entry);
          final product = Product.fromJson(normalizedMap);
          final rawSku = (entry['sku'] ?? entry['id'] ?? '').toString();
          final key = rawSku.isNotEmpty ? rawSku : product.id;

          if (key.isEmpty) continue;

          final existing = dedupedBySku[key];
          if (existing == null) {
            dedupedBySku[key] = product;
          } else {
            // Always prefer the newer file's live price, while preserving
            // richer fragrance notes if the older entry had them.
            final bestNotes = product.fragranceNotes.length >= existing.fragranceNotes.length
                ? product.fragranceNotes
                : existing.fragranceNotes;

            dedupedBySku[key] = Product.fromJson({
              ...normalizedMap,
              'fragranceNotes': bestNotes,
            });
          }
        }
        debugPrint('✅ [BBW Repo] Loaded ${decoded.length} items from $path');
      } catch (e) {
        // Only log if it's not a missing optional numbered variant
        if (!path.contains('_2.') && !path.contains('_3.') && !path.contains('_4.')) {
          debugPrint('⚠️ [BBW Repo] Asset not found in bundle: $path');
        }
      }
    }

    debugPrint(
      '🚀 [BBW Repo] Initialized ${dedupedBySku.length} unique SKUs across $filesLoadedCount files.',
    );

    _allUniqueProducts = dedupedBySku.values.toList();

    for (final key in _roomBuckets.keys) {
      _roomBuckets[key] = [];
    }

    for (final product in _allUniqueProducts) {
      final roomId = _resolveCanonicalRoom(product);
      _roomBuckets[roomId]!.add(product);
    }

    _isLoaded = true;
  }

  List<Product> getProductsForRoom(String roomId) {
    return _roomBuckets[roomId] ?? const [];
  }

  List<Product> getScentCollection(String scentKeyword) {
    final q = scentKeyword.toLowerCase().trim();
    return _allUniqueProducts
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  Map<String, dynamic> _normalizeRawProduct(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    final cleanName = (map['name'] ?? '')
        .toString()
        .replaceAll('&trade;', '™')
        .replaceAll('&reg;', '®')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    map['name'] = cleanName;

    final nameLower = cleanName.toLowerCase();
    final currentUnitShort = (map['unitShort'] ?? '').toString();

    if (currentUnitShort.isEmpty || currentUnitShort == 'Item') {
      if (nameLower.contains('4-wick')) {
        map['unit'] = '25.4 oz / 720 g';
        map['unitShort'] = '25.4 oz';
      } else if (nameLower.contains('fragrance booster')) {
        map['unit'] = '18 oz / 510 g';
        map['unitShort'] = '18 oz';
      } else if (nameLower.contains('laundry detergent')) {
        map['unit'] = '32 fl oz / 946 ml';
        map['unitShort'] = '32 oz';
      } else if (nameLower.contains('concentrated room spray')) {
        map['unit'] = '1.5 oz / 42.5 g';
        map['unitShort'] = '1.5 oz';
      } else if (nameLower.contains('room mist')) {
        map['unit'] = '5.3 fl oz / 156 ml';
        map['unitShort'] = '5.3 oz';
      } else if (nameLower.contains('car fragrance refill')) {
        map['unit'] = '0.2 fl oz / 6 ml';
        map['unitShort'] = '0.2 oz';
      } else if (nameLower.contains('pocketspray') ||
          nameLower.contains('hand sanitizer spray')) {
        map['unit'] = '3.3 fl oz / 97 ml';
        map['unitShort'] = '3.3 oz';
      } else if (nameLower.contains('hand sanitizer with pump')) {
        map['unit'] = '7.6 fl oz / 225 ml';
        map['unitShort'] = '7.6 oz';
      } else if (nameLower.contains('hand soap') ||
          nameLower.contains('foaming refill')) {
        map['unit'] = '8.75 fl oz / 259 ml';
        map['unitShort'] = '8.75 oz';
      } else if (nameLower.contains('body butter')) {
        map['unit'] = '6.5 oz / 185 g';
        map['unitShort'] = '6.5 oz';
      } else if (nameLower.contains('body scrub') ||
          nameLower.contains('sugar scrub')) {
        map['unit'] = '8 oz / 226 g';
        map['unitShort'] = '8 oz';
      } else if (nameLower.contains('bar soap') ||
          nameLower.contains('cleansing bar')) {
        map['unit'] = '5 oz / 141.75 g';
        map['unitShort'] = '5 oz';
      } else if (nameLower.contains('shower steamers')) {
        map['unit'] = '6 Tablets';
        map['unitShort'] = '6 pk';
      } else if (nameLower.contains('hand cream')) {
        map['unit'] = '1 fl oz / 29 ml';
        map['unitShort'] = '1 oz';
      } else if (nameLower.contains('lip oil') ||
          nameLower.contains('lip balm') ||
          nameLower.contains('lip mask') ||
          nameLower.contains('lip gloss')) {
        map['unit'] = '0.15 oz / 4.3 g';
        map['unitShort'] = 'Lip';
      } else if (nameLower.contains('diamond shimmer mist')) {
        map['unit'] = '4.9 fl oz / 145 ml';
        map['unitShort'] = '4.9 oz';
      } else if (nameLower.contains('essential oil mist')) {
        map['unit'] = '5.85 fl oz / 173 ml';
        map['unitShort'] = '5.85 oz';
      } else if (nameLower.contains('eau de parfum') &&
          !nameLower.contains('mini')) {
        map['unit'] = '1.7 fl oz / 50 ml';
        map['unitShort'] = '1.7 oz';
      } else if (nameLower.contains('cologne') && !nameLower.contains('mini')) {
        map['unit'] = '3.4 fl oz / 100 ml';
        map['unitShort'] = '3.4 oz';
      } else if (nameLower.contains('antiperspirant')) {
        map['unit'] = '2.7 oz / 77 g';
        map['unitShort'] = '2.7 oz';
      } else if (nameLower.contains('wallflowers fragrance plug')) {
        map['unit'] = 'Wall Plug';
        map['unitShort'] = 'Plug';
      } else if (nameLower.contains('car fragrance holder')) {
        map['unit'] = 'Visor Clip';
        map['unitShort'] = 'Holder';
      } else if (nameLower.contains('liquidless reeds') ||
          nameLower.contains('hanging fragrance diffuser')) {
        map['unit'] = 'Diffuser';
        map['unitShort'] = 'Diffuser';
      }
    }

    if (nameLower.contains('travel size') && nameLower.contains('mist')) {
      map['unit'] = '2.5 fl oz / 75 ml';
      map['unitShort'] = '2.5 oz';
    } else if (nameLower.contains('mini eau de parfum') ||
        nameLower.contains('rollerball')) {
      map['unit'] = '0.23 fl oz / 7 ml';
      map['unitShort'] = '0.23 oz';
    }

    return map;
  }

  String _resolveCanonicalRoom(Product product) {
    final name = product.name.toLowerCase();

    if (name.contains('candle') || name.contains('pedestal')) {
      return 'candles';
    }
    if (name.contains('wallflower') ||
        name.contains('room spray') ||
        name.contains('room mist') ||
        name.contains('car fragrance') ||
        name.contains('liquidless reeds') ||
        name.contains('hanging fragrance diffuser') ||
        name.contains('reed vessel')) {
      return 'wallflowers';
    }
    if (name.contains('hand soap') ||
        name.contains('foaming refill') ||
        name.contains('pocketbac') ||
        name.contains('hand sanitizer') ||
        name.contains('pocketspray') ||
        name.contains('soap holder')) {
      return 'soaps';
    }
    if (name.contains('laundry detergent') ||
        name.contains('fragrance booster') ||
        name.contains('dryer sheet')) {
      return 'home_care';
    }
    if (name.contains('travel size') ||
        name.contains('mini eau de parfum') ||
        name.contains('mini cologne') ||
        name.contains('rollerball') ||
        name.contains('hand cream') ||
        name.contains('mini gift set')) {
      return 'minis';
    }
    if (name.contains('3-in-1') ||
        name.contains('cologne') ||
        name.contains('deodorizing body spray') ||
        name.contains('antiperspirant') ||
        name.contains('mahogany teakwood gift set') ||
        _mensCoreScents.any((scent) => name.contains(scent))) {
      return 'mens';
    }
    if (name.contains('fine fragrance mist') ||
        name.contains('perfume mist') ||
        name.contains('eau de parfum') ||
        name.contains('solid perfume') ||
        name.contains('shimmer mist') ||
        name.contains('essential oil mist')) {
      return 'fragrance';
    }

    return 'body_care';
  }
}
