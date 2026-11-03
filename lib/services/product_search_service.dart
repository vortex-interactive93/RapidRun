import 'dart:convert';
import 'dart:collection';
import 'package:flutter/services.dart';
import '../models/product.dart';
import 'fuzzy_match.dart';
import 'search_aliases.dart';
import 'search_telemetry.dart';

/// Loads and searches product assets. Caches per store to minimize repeated decoding.
class ProductSearchService {
  ProductSearchService._();
  static final instance = ProductSearchService._();

  final Map<String, List<Product>> _cacheByStore = {};
  // Inverted index: store -> token -> set of products containing that token
  final Map<String, Map<String, Set<Product>>> _indexByStore = {};
  // Store -> (cacheKey -> results) with insertion order for simple LRU eviction.
  final Map<String, LinkedHashMap<String, List<Product>>> _resultCache = {};
  static const int _cacheCapacityPerStore = 50;
  bool _initialized = false;
  // Inferred brands per store (lazy filled once requested)
  final Map<String, Map<String, String>> _brandByProductId =
      {}; // storeKey -> (productId -> brand)
  final Map<String, List<String>> _brandsCache =
      {}; // storeKey -> distinct sorted brands
  // Recent queries (in-memory per session) storeKey -> queue (most recent first, dedup)
  final Map<String, List<String>> _recentQueries = {};
  static const int _maxRecentQueries = 10;

  // Simple size extraction cache: product id -> normalized size numeric (base units) for facet range
  final Map<String, double> _sizeCache = {};

  // Size ranges (in base units) for coarse filtering buckets.
  final List<_SizeRangeBucket> _sizeBuckets = const [
    _SizeRangeBucket('small', 0, 10), // e.g. single small items
    _SizeRangeBucket('medium', 10, 40),
    _SizeRangeBucket('large', 40, 120),
    _SizeRangeBucket('bulk', 120, double.infinity),
  ];

  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    final manifestRaw = await rootBundle.loadString('AssetManifest.json');
    final manifest = json.decode(manifestRaw) as Map<String, dynamic>;
    final productFiles = manifest.keys.where(
      (p) => p.startsWith('assets/stores/') && p.endsWith('.json'),
    );

    for (final path in productFiles) {
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = json.decode(raw);
        if (decoded is! List) continue;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final product = Product.fromJson(item);
            final store = (product.store ?? '').trim();
            if (store.isEmpty) continue;
            _cacheByStore
                .putIfAbsent(store.toLowerCase(), () => [])
                .add(product);
          }
        }
      } catch (_) {
        /* ignore individual file errors */
      }
    }
    _initialized = true;
  }

  void _buildIndex(String storeKey) {
    if (_indexByStore.containsKey(storeKey)) return;
    final products = _cacheByStore[storeKey];
    if (products == null) return;
    final Map<String, Set<Product>> tokenMap = {};
    for (final p in products) {
      final tokens = _tokenize(p);
      for (final t in tokens) {
        if (t.isEmpty) continue;
        tokenMap.putIfAbsent(t, () => <Product>{}).add(p);
      }
    }
    _indexByStore[storeKey] = tokenMap;
  }

  // Heuristic brand inference from product name (assets do not contain explicit brand field yet).
  String _inferBrand(Product p) {
    final name = p.name.trim();
    if (name.isEmpty) return '';
    final lower = name.toLowerCase();
    // Curated multi-word / special brands to detect before generic token logic.
    const knownBrands = [
      'great value',
      'morningstar farms',
      'pictsweet farms',
      'haagen dazs',
      'scott & jon',
      'scott & jon\'s',
      'lean cuisine',
      'healthy choice',
      'little bites',
      'golden krust',
      'realgood foods',
      'beyond meat',
      'tyson',
      'perdue',
      'outshine',
      'funpops',
      'drumstick',
    ];
    for (final kb in knownBrands) {
      if (lower.startsWith(kb)) {
        // Normalize apostrophe variants.
        return kb
            .replaceAll("jon'", "Jon\'")
            .split(' ')
            .map((w) => _capitalize(w))
            .join(' ');
      }
    }
    // Split on comma first (brands rarely include commas) keep first segment
    final primary = name.split(',').first;
    final tokens = primary.split(RegExp(r'\s+'));
    final collected = <String>[];
    for (final t in tokens) {
      if (t.isEmpty) continue;
      // Stop if token starts with a digit (quantity) or is length 1 punctuation.
      if (RegExp(r'^\d').hasMatch(t)) break;
      // Allow alphanumeric/ampersand/quotes/hyphen
      // Allow alphanumeric plus & ' - characters; strip others.
      final cleaned = t.replaceAll(RegExp(r"[^A-Za-z0-9&'\-]"), '');
      if (cleaned.isEmpty) continue;
      // If lowercase start and we have already one token, stop (brand normally capitalized).
      final isCapitalized = RegExp(r'^[A-Z]').hasMatch(cleaned);
      if (!isCapitalized) {
        if (collected.isNotEmpty)
          break;
        else
          collected.add(cleaned); // fallback first lower
      } else {
        collected.add(cleaned);
      }
      if (collected.length >= 2) break; // limit to two words for brand brevity
    }
    final brand = collected.join(' ').trim();
    return brand;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _ensureBrands(String storeKey) {
    if (_brandsCache.containsKey(storeKey)) return;
    final products = _cacheByStore[storeKey];
    if (products == null) return;
    final map = <String, String>{};
    final distinct = <String>{};
    for (final p in products) {
      final b = _inferBrand(p);
      if (b.isEmpty) continue;
      map[p.id] = b;
      distinct.add(b);
    }
    final list = distinct.toList()..sort();
    _brandByProductId[storeKey] = map;
    _brandsCache[storeKey] = list;
  }

  Iterable<String> _tokenize(Product p) sync* {
    String lc(String? s) => (s ?? '').toLowerCase();
    final name = lc(p.name);
    for (final part in name.split(RegExp(r'[^a-z0-9]+'))) {
      if (part.isNotEmpty) yield part;
    }
    for (final tag in p.tags) {
      final lt = lc(tag);
      if (lt.isNotEmpty) yield lt;
    }
    if (p.category != null) {
      final c = lc(p.category);
      if (c.isNotEmpty) yield c;
    }
    if (p.subCategory != null) {
      final c = lc(p.subCategory);
      if (c.isNotEmpty) yield c;
    }
  }

  /// Search within a single store (case-insensitive). Returns up to [limit] results.
  Future<List<Product>> searchStore(
    String store,
    String query, {
    int limit = 50,
    String? categoryFilter,
    String? brandFilter,
    String?
    sizeRangeFilter, // one of size bucket ids (small, medium, large, bulk)
    bool enableFuzzy = false,
    bool useCache = true,
    bool boostPopularity = true,
    Map<String, double>? popularityOverride, // test/diagnostic override
  }) async {
    await _ensureLoaded();
    final key = store.toLowerCase();
    final list = _cacheByStore[key];
    if (list == null) return [];
    _buildIndex(key);
    final rawQ = query.trim().toLowerCase();
    if (rawQ.isEmpty) return [];
    final q = _normalizeQuery(rawQ);
    final cacheKey =
        '${q}::f:${enableFuzzy ? 1 : 0}::c:${categoryFilter ?? '*'}::b:${brandFilter ?? '*'}::s:${sizeRangeFilter ?? '*'}::l:$limit::p:${boostPopularity ? 1 : 0}';
    if (useCache) {
      final cache = _resultCache.putIfAbsent(key, () => LinkedHashMap());
      final cached = cache[cacheKey];
      if (cached != null) {
        return List<Product>.from(cached);
      }
    }
    // Alias expansion: if query token matches a key, append its aliases for scoring consideration.
    final aliasTokens = <String>{};
    final qTokens = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    for (final token in qTokens) {
      final aliases = kSearchAliases[token];
      if (aliases != null) {
        for (final a in aliases) {
          aliasTokens.add(a.toLowerCase());
        }
      }
    }
    final List<_ScoredProduct> scored = [];
    final tokens = qTokens;
    // Candidate narrowing using inverted index when fuzzy disabled.
    Iterable<Product> candidateIterable = list;
    if (!enableFuzzy) {
      final index = _indexByStore[key];
      if (index != null && index.isNotEmpty) {
        final Set<Product> candidates = <Product>{};
        if (tokens.length == 1) {
          final t = tokens.first;
          // Exact token matches
          final exact = index[t];
          if (exact != null) candidates.addAll(exact);
          // Prefix & substring token matches (iterate keys; acceptable since key set << products)
          for (final k in index.keys) {
            if (k == t) continue;
            if (k.startsWith(t) || (t.length > 2 && k.contains(t))) {
              final set = index[k];
              if (set != null) candidates.addAll(set);
            }
          }
        } else {
          for (final t in tokens) {
            final set = index[t];
            if (set != null) candidates.addAll(set);
          }
        }
        if (candidates.isNotEmpty) {
          candidateIterable = candidates;
        }
      }
    }
    // Record recent query (prefix only if user typed >=2 chars)
    if (rawQ.length >= 2) _recordRecentQuery(key, rawQ);

    Map<String, double> popularity = popularityOverride ?? const {};
    if (popularityOverride == null && boostPopularity) {
      try {
        popularity = await SearchTelemetry.instance.productPopularityScores(
          store,
        );
      } catch (_) {
        /* ignore telemetry failure */
      }
    }

    for (final p in candidateIterable) {
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        final cat = (p.category ?? '').toLowerCase();
        if (cat != categoryFilter.toLowerCase()) continue;
      }
      if (brandFilter != null && brandFilter.isNotEmpty) {
        final brand = inferredBrand(store, p).toLowerCase();
        if (brand != brandFilter.toLowerCase()) continue;
      }
      if (sizeRangeFilter != null && sizeRangeFilter.isNotEmpty) {
        final bucket = _sizeBuckets.firstWhere(
          (b) => b.id == sizeRangeFilter,
          orElse: () => const _SizeRangeBucket('none', 0, 0),
        );
        if (bucket.id != 'none') {
          final sz = _extractSizeBaseUnits(p);
          if (sz == null || sz < bucket.min || sz >= bucket.max) continue;
        }
      }
      double score = _scoreProduct(p, q, aliasTokens: aliasTokens);
      if (score <= 0 && enableFuzzy && tokens.length == 1) {
        // Attempt fuzzy match against name tokens & tags with distance <=1 (or 2 if length >5)
        final nameTokens = p.name.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
        final maxDist = q.length > 5 ? 2 : 1;
        bool matched = false;
        for (final nt in nameTokens) {
          if (nt.isEmpty) continue;
          if (FuzzyMatch.withinDistance(tokens[0], nt, maxDist)) {
            matched = true;
            break;
          }
        }
        if (!matched) {
          for (final t in p.tags) {
            final lt = t.toLowerCase();
            if (FuzzyMatch.withinDistance(tokens[0], lt, maxDist)) {
              matched = true;
              break;
            }
          }
        }
        if (matched) {
          score = 18 - p.name.length * 0.01;
        }
      }
      if (score > 0) {
        final pop = popularity[p.id];
        if (pop != null && pop > 0) {
          // Map raw popularity weight (typically < number of clicks) to a small boost.
          // Use natural log for diminishing returns.
          final boost = 8 * (1 + (pop > 0.001 ? (MathHelper.ln(1 + pop)) : 0));
          score += boost;
        }
        scored.add(_ScoredProduct(p, score));
      }
    }
    scored.sort((a, b) {
      final r = b.score.compareTo(a.score);
      if (r != 0) return r;
      return a.product.name.compareTo(b.product.name);
    });
    final resultList = scored.take(limit).map((e) => e.product).toList();
    if (useCache) {
      final cache = _resultCache.putIfAbsent(key, () => LinkedHashMap());
      cache[cacheKey] = resultList;
      if (cache.length > _cacheCapacityPerStore) {
        cache.remove(cache.keys.first);
      }
    }
    return resultList;
  }

  // Basic normalization: collapse hyphens to spaces, singularize simple trailing 's'
  // (but avoid words ending with 'ss' or length <4), and map some irregulars.
  String _normalizeQuery(String q) {
    var out = q.replaceAll('-', ' ');
    // Irregular small map
    const irregular = {
      'fries': 'fries', // keep plural as base
      'chips': 'chips',
    };
    if (irregular.containsKey(out)) return irregular[out]!;
    // Singularize each token
    final tokens = out.split(RegExp(r'\s+')).map((t) {
      if (t.length < 4) return t;
      if (t.endsWith('ses') || t.endsWith('ies')) {
        // Simple 'ies' -> 'y'
        if (t.endsWith('ies') && t.length > 4) {
          return t.substring(0, t.length - 3) + 'y';
        }
        return t;
      }
      if (t.endsWith('s') && !t.endsWith('ss')) {
        return t.substring(0, t.length - 1);
      }
      return t;
    }).toList();
    out = tokens.join(' ');
    return out.trim();
  }

  /// Returns distinct categories (lowercase preserved original case) for a store.
  Future<List<String>> categoriesForStore(String store) async {
    await _ensureLoaded();
    final list = _cacheByStore[store.toLowerCase()];
    if (list == null) return const [];
    final set = <String>{};
    for (final p in list) {
      final c = p.category?.trim();
      if (c != null && c.isNotEmpty) set.add(c);
    }
    final sorted = set.toList()..sort();
    return sorted;
  }

  double _scoreProduct(Product p, String q, {Set<String>? aliasTokens}) {
    double score = 0;
    final name = p.name.toLowerCase();
    final tags = p.tags.map((e) => e.toLowerCase()).toList();
    final cat = (p.category ?? '').toLowerCase();
    final sub = (p.subCategory ?? '').toLowerCase();
    // Exact prefix in name
    if (name.startsWith(q)) score += 120;
    // Word boundary match in name
    if (RegExp('(^|\\s)${RegExp.escape(q)}').hasMatch(name)) score += 70;
    // Tag matches
    for (final t in tags) {
      if (t == q)
        score += 80;
      else if (t.startsWith(q))
        score += 50;
      else if (t.contains(q))
        score += 25;
    }
    // Category / subcategory
    if (cat == q)
      score += 40;
    else if (cat.contains(q))
      score += 15;
    if (sub == q)
      score += 35;
    else if (sub.contains(q))
      score += 12;
    // Generic substring in name
    if (score == 0 && name.contains(q)) score += 20;
    // Alias matches (mild boost if any alias occurs as word boundary)
    if (aliasTokens != null && aliasTokens.isNotEmpty) {
      for (final alias in aliasTokens) {
        final pattern = RegExp('(^|\\s)${RegExp.escape(alias)}(\\s|\\b)');
        if (pattern.hasMatch(name) ||
            tags.contains(alias) ||
            cat == alias ||
            sub == alias) {
          score += 15;
          break;
        }
      }
    }
    // Slight boost for shorter names when tie
    score -= name.length * 0.01;
    return score;
  }

  /// Public accessor to list of inferred brands for a store (sorted ascending)
  Future<List<String>> brandsForStore(String store) async {
    await _ensureLoaded();
    final key = store.toLowerCase();
    _ensureBrands(key);
    return _brandsCache[key] ?? const [];
  }

  /// Returns inferred brand for a product (empty string if not determined)
  String inferredBrand(String store, Product p) {
    final key = store.toLowerCase();
    _ensureBrands(key);
    return _brandByProductId[key]?[p.id] ?? _inferBrand(p);
  }

  // --- Autocomplete / Suggestions API ---

  /// Returns suggestion strings ranked by relevance for a given partial query within a store.
  /// Combines: recent queries (prefix match), brand names, product name tokens, and alias expansions.
  Future<List<String>> suggest(
    String store,
    String partial, {
    int limit = 8,
  }) async {
    await _ensureLoaded();
    final key = store.toLowerCase();
    final p = partial.trim().toLowerCase();
    if (p.isEmpty) return _recentQueries[key] ?? const [];
    final suggestions = <_ScoredSuggestion>[];

    // 1. Recent queries
    for (final q in (_recentQueries[key] ?? const [])) {
      if (q.startsWith(p)) {
        suggestions.add(_ScoredSuggestion(q, 120.0 - q.length.toDouble()));
      }
    }
    // 2. Brands
    _ensureBrands(key);
    for (final b in (_brandsCache[key] ?? const [])) {
      final bl = b.toLowerCase();
      if (bl.startsWith(p)) {
        suggestions.add(_ScoredSuggestion(b, 100.0 - b.length * 0.5));
      } else if (p.length > 2 && bl.contains(p)) {
        suggestions.add(_ScoredSuggestion(b, 80.0 - b.length * 0.4));
      }
    }
    // 3. Product tokens / full names (prefix)
    final products = _cacheByStore[key] ?? const [];
    final seen = <String>{};
    for (final prod in products) {
      final nameL = prod.name.toLowerCase();
      if (nameL.startsWith(p)) {
        if (seen.add(prod.name)) {
          suggestions.add(
            _ScoredSuggestion(prod.name, 95.0 - nameL.length * 0.3),
          );
        }
      } else {
        for (final token in nameL.split(RegExp(r'[^a-z0-9]+'))) {
          if (token.isEmpty || token == p) continue;
          if (token.startsWith(p) && seen.add(token)) {
            suggestions.add(
              _ScoredSuggestion(token, 60.0 - token.length * 0.2),
            );
          }
        }
      }
    }
    // 4. Alias expansions (if user typed an alias prefix)
    for (final entry in kSearchAliases.entries) {
      final keyAlias = entry.key;
      if (keyAlias.startsWith(p)) {
        suggestions.add(
          _ScoredSuggestion(keyAlias, 70.0 - keyAlias.length * 0.2),
        );
      }
      for (final v in entry.value) {
        if (v.startsWith(p)) {
          suggestions.add(_ScoredSuggestion(v, 65.0 - v.length * 0.2));
        }
      }
    }
    suggestions.sort((a, b) => b.score.compareTo(a.score));
    final out = <String>[];
    for (final s in suggestions) {
      if (out.contains(s.value)) continue;
      out.add(s.value);
      if (out.length >= limit) break;
    }
    return out;
  }

  void _recordRecentQuery(String storeKey, String q) {
    final list = _recentQueries.putIfAbsent(storeKey, () => []);
    list.remove(q);
    list.insert(0, q);
    if (list.length > _maxRecentQueries)
      list.removeRange(_maxRecentQueries, list.length);
  }

  /// Returns available size range bucket ids for a store that actually contain products.
  Future<List<String>> sizeRangeBuckets(String store) async {
    await _ensureLoaded();
    final key = store.toLowerCase();
    final products = _cacheByStore[key] ?? const [];
    final used = <String>{};
    for (final p in products) {
      final sz = _extractSizeBaseUnits(p);
      if (sz == null) continue;
      for (final b in _sizeBuckets) {
        if (sz >= b.min && sz < b.max) used.add(b.id);
      }
    }
    final list = used.toList()..sort();
    return list;
  }

  double? _extractSizeBaseUnits(Product p) {
    // Attempt to parse from name first (consistent with variant logic), else unit/unitShort fields.
    final name = p.name.toLowerCase();
    double? val;
    // Multi pattern (e.g., 12 x 12 fl oz) approximate total content -> count * each size
    final multi = RegExp(
      r'(\d+)\s?[xX]\s?(\d+(?:\.\d+)?)\s?(fl\s?oz|oz|ml|l|g|lb)',
    ).firstMatch(name);
    if (multi != null) {
      final c = double.tryParse(multi.group(1)!) ?? 0;
      final each = double.tryParse(multi.group(2)!) ?? 0;
      val =
          c *
          _convertToBaseUnit(
            each.toString(),
            multi.group(3)!,
          ); // reuse existing converter logic via string
    } else {
      final single = RegExp(
        r'(\d+(?:\.\d+)?)\s?(fl\s?oz|oz|ml|l|g|lb)',
      ).firstMatch(name);
      if (single != null) {
        val = _convertToBaseUnit(single.group(1)!, single.group(2)!);
      }
    }
    if (val == null || val == 0) {
      // fallback parse from unit/unitShort fields
      final u = p.unitShort ?? p.unit;
      if (u != null) {
        final m = RegExp(
          r'(\d+(?:\.\d+)?)\s?(fl\s?oz|oz|ml|l|g|lb)',
        ).firstMatch(u.toLowerCase());
        if (m != null) {
          val = _convertToBaseUnit(m.group(1)!, m.group(2)!);
        }
      }
    }
    if (val != null && val > 0) _sizeCache[p.id] = val;
    return val;
  }

  /// TEST SUPPORT ONLY: injects products for a store and bypasses asset loading.
  /// This allows deterministic unit tests for search & ranking without large asset overhead.
  void setTestProducts(String store, List<Product> products) {
    final key = store.toLowerCase();
    _cacheByStore[key] = List<Product>.from(products);
    _indexByStore.remove(key);
    _resultCache.remove(key);
    _brandByProductId.remove(key);
    _brandsCache.remove(key);
    _recentQueries.remove(key);
    // Mark initialized so _ensureLoaded skips full asset scan in tests.
    _initialized = true;
  }
}

class _ScoredProduct {
  final Product product;
  final double score;
  _ScoredProduct(this.product, this.score);
}

class _ScoredSuggestion {
  final String value;
  final double score;
  _ScoredSuggestion(this.value, this.score);
}

class _SizeRangeBucket {
  final String id;
  final double min;
  final double max;
  const _SizeRangeBucket(this.id, this.min, this.max);
}

double _convertToBaseUnit(String numStr, String unitRaw) {
  final v = double.tryParse(numStr) ?? 0;
  final u = unitRaw.toLowerCase().replaceAll(' ', '');
  if (u == 'floz') return v; // base fluid oz
  if (u == 'oz') return v; // treat ounce same scale
  if (u == 'ml') return v / 29.5735; // ml to fl oz
  if (u == 'l') return v * 33.814; // liters to fl oz
  if (u == 'g') return v / 28.3495; // grams to ounces
  if (u == 'lb') return v * 16; // pounds to ounces
  return v;
}
