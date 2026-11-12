// File: lib/services/bbw_boutique_repository.dart

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';

class BbwBoutiqueRepository {
  static final BbwBoutiqueRepository instance = BbwBoutiqueRepository._();
  BbwBoutiqueRepository._();

  /// Ordered from oldest/fallback to newest scraped files.
  /// Later files in this list ALWAYS overwrite older prices for the same SKU.
  static const List<String> _allAssetFiles = [
    // Canonical 8 filenames
    'assets/data/candles.json',
    'assets/data/body_care.json',
    'assets/data/all_fragrance.json',
    'assets/data/mini_and_travel_size.json',
    'assets/data/hand_soaps_sanitizers.json',
    'assets/data/wallflowers_diffusers.json',
    'assets/data/mens_shop.json',
    'assets/data/home_care.json',
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

  /// Deletes all Bath & Body Works documents from Firestore so stale prices
  /// never resurrect from cloud cache.
  Future<void> purgeAllBbwFromFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final byStore = await firestore
          .collection('products')
          .where('store', isEqualTo: 'Bath & Body Works')
          .get();

      final byStoreId = await firestore
          .collection('products')
          .where('storeId', isEqualTo: 'Bath & Body Works')
          .get();

      final allDocs = <String, DocumentReference>{};
      for (final doc in byStore.docs) {
        allDocs[doc.id] = doc.reference;
      }
      for (final doc in byStoreId.docs) {
        allDocs[doc.id] = doc.reference;
      }

      if (allDocs.isEmpty) {
        debugPrint('🧹 [BBW Purge] Firestore is already 100% clean (0 BBW docs).');
        return;
      }

      final refs = allDocs.values.toList();
      for (var i = 0; i < refs.length; i += 450) {
        final batch = firestore.batch();
        final chunk = refs.sublist(i, i + 450 > refs.length ? refs.length : i + 450);
        for (final ref in chunk) {
          batch.delete(ref);
        }
        await batch.commit();
      }

      debugPrint('🔥 [BBW Purge] Successfully deleted ${refs.length} stale BBW documents from Firestore.');
    } catch (e) {
      debugPrint('⚠️ [BBW Purge] Firestore cleanup error: $e');
    }
  }

  /// Loads, deduplicates by SKU, sanitizes HTML entities, normalizes units,
  /// and routes every product to its true canonical Boutique Room.
  Future<void> ensureInitialized({bool forceReload = false}) async {
    if (forceReload) resetCache();
    if (_isLoaded) return;

    // Purge stale BBW documents in background so local JSON loading completes instantly (<50ms)!
    unawaited(purgeAllBbwFromFirestore().catchError((e) {
      debugPrint('⚠️ [BBW Purge] Background Firestore cleanup notice: $e');
    }));

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
        debugPrint('⚠️ [BBW Repo] Asset not found in bundle: $path');
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

    // Olfactory Vault Fallback Enrichment for items missing scent notes
    final List<dynamic> existingNotes = (map['fragranceNotes'] as List?) ?? [];
    if (existingNotes.isEmpty) {
      for (final entry in _scentVault.entries) {
        if (nameLower.contains(entry.key)) {
          map['fragranceNotes'] = entry.value['notes'];
          if ((map['fragranceOverview'] ?? '').toString().trim().isEmpty) {
            map['fragranceOverview'] = entry.value['overview'];
          }
          final tiers = entry.value['tiers'] as Map<String, dynamic>?;
          if (tiers != null) {
            map['fragranceTiers'] = tiers;
            map['fragranceProfile'] = {
              'family': 'Fragrance',
              'topNotes': tiers['top'] ?? [],
              'heartNotes': tiers['heart'] ?? [],
              'baseNotes': tiers['base'] ?? [],
            };
          }
          break;
        }
      }
    }

    return map;
  }

  static const Map<String, Map<String, dynamic>> _scentVault = {
    'lakeside morning': {
      'notes': ['crisp autumn air', 'white driftwood', 'green apple'],
      'overview': 'As cool, fresh and rejuvenating as an early morning by the lake.',
      'tiers': {'top': ['green apple'], 'heart': ['crisp autumn air'], 'base': ['white driftwood']}
    },
    'snowflakes & cashmere': {
      'notes': ['vanilla cashmere cream', 'caramel woods', 'frosted clementine'],
      'overview': 'Creamy, warm vanilla blends with refreshing citrus notes for an oh-so-snuggly scent.',
      'tiers': {'top': ['frosted clementine'], 'heart': ['vanilla cashmere cream'], 'base': ['caramel woods']}
    },
    'fresh balsam': {
      'notes': ['woodland balsam', 'crisp eucalyptus', 'fir branches', 'cedarwood'],
      'overview': 'As cool, fresh and rejuvenating as an early November walk through the woods.',
      'tiers': {'top': ['crisp eucalyptus'], 'heart': ['fir branches'], 'base': ['woodland balsam', 'cedarwood']}
    },
    'mahogany teakwood': {
      'notes': ['juniper berry', 'bergamot', 'red berries', 'cypress leaves', 'fresh lavender', 'creamy sandalwood', 'driftwood', 'rich mahogany wood', 'black teakwood'],
      'overview': 'Warm, distinctive and enduring. Deep mahogany and solid black teakwood with a dash of lavender.',
      'tiers': {'top': ['juniper berry', 'bergamot'], 'heart': ['fresh lavender'], 'base': ['rich mahogany wood', 'black teakwood']}
    },
    'champagne toast': {
      'notes': ['Kir royale', 'vintage Champagne', 'sparkling tangerine', 'juicy passionfruit', 'dark plum', 'white nectarine', 'black currant', 'warm woods', 'sugared musk', 'vanilla extract'],
      'overview': 'With the effervescence of Champagne, ripe berries and sweet tangerine.',
      'tiers': {'top': ['Kir royale', 'vintage Champagne'], 'heart': ['sparkling tangerine'], 'base': ['sugared musk']}
    },
    'a thousand wishes': {
      'notes': ['pink prosecco', 'starfruit', 'golden quince', 'crystal peonies', 'purple freesia', 'gilded amber', 'amaretto crème', 'sugared sandalwood', 'velvet musk'],
      'overview': 'Enter a world of endless possibilities. Shimmering prosecco, swirling fruit, florals and creamy amaretto.',
      'tiers': {'top': ['pink prosecco', 'starfruit'], 'heart': ['crystal peonies'], 'base': ['gilded amber', 'sugared sandalwood']}
    },
    'warm vanilla sugar': {
      'notes': ['sheer muguet', 'coconut milk', 'white orchid', 'jasmine', 'vanilla absolute', 'warm musk', 'sugar crystals', 'sandalwood'],
      'overview': 'Addictive by nature. Refined by design. A balance of gourmand comfort and all-day wearable elegance.',
      'tiers': {'top': ['sheer muguet'], 'heart': ['coconut milk'], 'base': ['vanilla absolute', 'warm musk']}
    },
    'vanilla bean noel': {
      'notes': ['vanilla', 'sweet buttery accord', 'caramel', 'benzoin', 'hint of chocolate', 'soft musk', 'sugar cookie'],
      'overview': 'Sweet, creamy and every bit as irresistible as you remember.',
      'tiers': {'top': ['vanilla', 'sweet buttery accord'], 'heart': ['caramel'], 'base': ['soft musk', 'sugar cookie']}
    },
    'japanese cherry blossom': {
      'notes': ['crisp pear', 'apple', 'ume plum', 'Japanese cherry blossom', 'white jasmine', 'butterfly lily', 'Kyoto rose', 'mimosa petals', 'rice milk', 'amber', 'silk musk', 'creamy sandalwood'],
      'overview': 'Feminine, floral, elegant and timelessly appealing.',
      'tiers': {'top': ['crisp pear'], 'heart': ['Japanese cherry blossom'], 'base': ['creamy sandalwood']}
    },
    'into the night': {
      'notes': ['pink pomelo', 'dewberry', 'black raspberry sugar', 'Turkish rose petals', 'jasmine sambac', 'patchouli', 'vanilla bean', 'mocha', 'amber', 'musk'],
      'overview': 'Glamorous with a modern, feminine signature. A woody amber chypre.',
      'tiers': {'top': ['pink pomelo'], 'heart': ['Turkish rose petals'], 'base': ['amber', 'musk']}
    },
    'in the stars': {
      'notes': ['sugared tangelo', 'pink currant', 'starflower', 'apricot blossom', 'jasmine absolute', 'sandalwood', 'white musk', 'white agarwood', 'amber', 'moss'],
      'overview': 'A fusion of sparkling highs and sophisticated depths.',
      'tiers': {'top': ['sugared tangelo'], 'heart': ['starflower'], 'base': ['sandalwood', 'white musk']}
    },
    'ocean': {
      'notes': ['bergamot', 'yuzu', 'artemisia', 'elemi', 'watermelon', 'lavandin', 'nutmeg', 'cypress', 'iris', 'cedarwood', 'patchouli', 'vetiver', 'olibanum'],
      'overview': 'Refreshing, vital and confident. Watery marine notes and woods.',
      'tiers': {'top': ['bergamot'], 'heart': ['cypress'], 'base': ['cedarwood', 'patchouli']}
    },
    'bourbon': {
      'notes': ['white pepper', 'dark amber', 'Kentucky oak'],
      'overview': 'Bold, smooth and classic barrel-aged bourbon.',
      'tiers': {'top': ['white pepper'], 'heart': ['dark amber'], 'base': ['Kentucky oak']}
    },
    'noir': {
      'notes': ['black cardamom', 'smoky vanilla', 'warm musk'],
      'overview': 'Dark, mysterious and endlessly warm.',
      'tiers': {'top': ['black cardamom'], 'heart': ['smoky vanilla'], 'base': ['warm musk']}
    },
    'graphite': {
      'notes': ['sage', 'bergamot spice', 'leather woods'],
      'overview': 'Fresh earthy greens meet warm citrus pepper and a rugged timber finish.',
      'tiers': {'top': ['bergamot spice'], 'heart': ['sage'], 'base': ['leather woods']}
    },
    'santal ridge': {
      'notes': ['bergamot zest', 'crisp aromatics', 'fresh fig leaf', 'Anjou pear', 'sheer iris', 'blue jasmine', 'wild moss', 'silver amber', 'rich sandalwood'],
      'overview': 'An untamed exploration of citrus, woods and moss.',
      'tiers': {'top': ['bergamot zest'], 'heart': ['sheer iris'], 'base': ['rich sandalwood']}
    },
    'twisted peppermint': {
      'notes': ['sweet peppermint', 'raspberry', 'sheer jasmine', 'candy floss', 'mint', 'musk'],
      'overview': 'A peppermint-striped holiday treat wrapped in frosty freshness.',
      'tiers': {'top': ['sweet peppermint'], 'heart': ['raspberry'], 'base': ['mint', 'musk']}
    },
    'winter candy apple': {
      'notes': ['juicy Granny Smith apple', 'sweet orange', 'candied red berries', 'delicate lily of the valley', 'sugared cinnamon bark', 'soft iris', 'golden cedarwood', 'frosted musk', 'oakmoss'],
      'overview': 'Cheerful, fruity and as bright as the season itself.',
      'tiers': {'top': ['juicy Granny Smith apple'], 'heart': ['delicate lily of the valley'], 'base': ['golden cedarwood']}
    },
    'strawberry pound cake': {
      'notes': ['fresh strawberries', 'golden shortcake', 'whipped cream'],
      'overview': 'Sweet, light and creamy, it is that classic dessert you just cannot get enough of.',
      'tiers': {'top': ['fresh strawberries'], 'heart': ['golden shortcake'], 'base': ['whipped cream']}
    },
    'sweet pea': {
      'notes': ['sweet pea', 'watery pear', 'sheer freesia', 'luscious raspberry', 'soft musk'],
      'overview': 'Bright, cheerful, and playfully sweet.',
      'tiers': {'top': ['watery pear'], 'heart': ['sweet pea'], 'base': ['soft musk']}
    },
    'black cherry merlot': {
      'notes': ['dark cherry', 'black raspberry', 'sumptuous merlot'],
      'overview': 'Rich, fruity, and elegantly decadent.',
      'tiers': {'top': ['dark cherry'], 'heart': ['black raspberry'], 'base': ['sumptuous merlot']}
    },
    'eucalyptus spearmint': {
      'notes': ['eucalyptus oil', 'spearmint oil'],
      'overview': 'Clears the mind and uplifts the spirits.',
      'tiers': {'top': ['eucalyptus oil'], 'heart': ['spearmint oil'], 'base': ['eucalyptus oil']}
    },
  };

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
