import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/product.dart';
import '../../services/product_search_service.dart';
import '../../services/search_telemetry.dart';
import '../../services/experiment_service.dart';
import '../../services/personalization_service.dart';
import '../../widgets/product/product_card_v2.dart';
import '../../widgets/shimmer_box.dart';
// Removed SearchDebugScreen (internal telemetry view) from consumer build.
// import 'search_debug_screen.dart';
import '../../theme/store_branding.dart';
import '../product_list_screen.dart';
import '../product_detail_screen.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

/// Rebuilt store search screen (temporary minimal stable version).
/// Goal: compile successfully while preserving key personalization & telemetry.
class StoreSearchScreen extends StatefulWidget {
  final String store;
  const StoreSearchScreen({super.key, required this.store});
  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  List<Product> _results = const [];
  List<Product> _topPicks = const [];
  bool _loading = false;
  bool _initial = true;
  bool _fuzzy = false;
  bool _autoFuzzyApplied = false;
  bool _popBoost = false;
  String _variant = 'A';

  // Filters & state
  List<String> _categories = const [];
  String? _selectedCategory;
  List<String> _brands = const [];
  String? _selectedBrand;
  bool _multipackOnly = false;
  String _sort = 'relevance';

  // Personalization caches
  Map<String, double> _groupScores = const {};
  Map<String, double> _productScores = const {};
  double _maxProductScore = 0;
  final Set<String> _quick = {};
  final Map<String, bool> _expanded = {};
  Map<String, String> _brandCache = const {};
  final Map<String, double> _productScoreCache =
      {}; // persistent across searches
  int _searchSeq = 0; // incrementing sequence to guard stale async results
  final ScrollController _scroll = ScrollController();
  bool _showToTop = false;

  // Recent + hero persistence
  final List<String> _recent = [];
  bool _heroDismissed = false;
  static const _heroDismissHours = 12;

  // Debounce
  static const _debounceMs = 300;
  DateTime _lastInput = DateTime.fromMillisecondsSinceEpoch(0);
  bool _scheduled = false;
  String? _pendingPrefillCategory;

  // Pref keys
  String _recentKey() => 'recent_search_${widget.store}';
  String _sortKey() => 'search_sort_${widget.store}';
  String _brandKey() => 'search_brand_${widget.store}';
  String _multiKey() => 'search_multi_${widget.store}';
  String _heroKey() => 'hero_dismiss_${widget.store.toLowerCase()}';
  String _quickKey() => 'search_quick_${widget.store}';

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadPrefs();
    _loadMeta();
    _loadHeroDismissed();
    _scroll.addListener(() {
      final show = _scroll.offset > 600;
      if (show != _showToTop && mounted) {
        setState(() => _showToTop = show);
      }
    });
    if (widget.store == 'taco_bell') _loadTacoBellCategoriesFull();
    if (widget.store == 'panda_express') _loadPandaExpressCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pendingPrefillCategory == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final pc = args['prefillCategory']?.toString();
        if (pc != null && pc.trim().isNotEmpty) {
          _pendingPrefillCategory = pc.trim();
          _tryApplyPrefill();
        }
      }
    }
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentKey()) ?? [];
    setState(() => _recent.addAll(raw));
  }

  Future<void> _persistRecent() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(_recentKey(), _recent);
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sort = prefs.getString(_sortKey()) ?? _sort;
      _selectedBrand = prefs.getString(_brandKey());
      _multipackOnly = prefs.getBool(_multiKey()) ?? false;
      final savedQuick = prefs.getStringList(_quickKey());
      if (savedQuick != null) {
        _quick
          ..clear()
          ..addAll(savedQuick);
      }
    });
  }

  Future<void> _loadHeroDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_heroKey());
    if (raw != null) {
      final ts = int.tryParse(raw);
      if (ts != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        if (DateTime.now().difference(dt).inHours < _heroDismissHours) {
          setState(() => _heroDismissed = true);
        }
      }
    }
  }

  Future<void> _loadMeta() async {
    final cats = await ProductSearchService.instance.categoriesForStore(
      widget.store,
    );
    final brands = await ProductSearchService.instance.brandsForStore(
      widget.store,
    );
    List<String> ordered = cats;
    try {
      ordered = await PersonalizationService.instance.rankedCategories(
        widget.store,
        List<String>.from(cats),
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _categories = ordered;
      _brands = brands;
    });
    _tryApplyPrefill();
  }

  void _tryApplyPrefill() {
    if (_pendingPrefillCategory == null || _categories.isEmpty) return;
    final lower = _pendingPrefillCategory!.toLowerCase();
    final m = _categories.firstWhere(
      (c) => c.toLowerCase() == lower,
      orElse: () => '',
    );
    if (m.isEmpty) return;
    setState(() {
      _selectedCategory = m;
      if (_controller.text.trim().isEmpty) _controller.text = m;
    });
    _runSearch(_controller.text);
    _pendingPrefillCategory = null;
  }

  void _schedule(String value) {
    _lastInput = DateTime.now();
    if (_scheduled) return;
    _scheduled = true;
    Future.delayed(const Duration(milliseconds: _debounceMs), () {
      final diff = DateTime.now().difference(_lastInput).inMilliseconds;
      if (diff >= _debounceMs) {
        final q = _controller.text.trim();
        if (q.isNotEmpty) _runSearch(q);
        _scheduled = false;
      } else {
        _scheduled = false;
        _schedule(value);
      }
    });
  }

  Future<void> _runSearch(String q) async {
    final int seq = ++_searchSeq; // capture sequence id
    setState(() {
      _loading = true;
      _autoFuzzyApplied = false;
      _groupScores = const {};
      _productScores = const {};
      _maxProductScore = 0;
      _brandCache = const {};
    });
    final started = DateTime.now();
    await ExperimentService.instance.ensureLoaded();
    if (!mounted || seq != _searchSeq) return;
    _popBoost = ExperimentService.instance.popularityBoostEnabled();
    _variant = ExperimentService.instance.variant;
    var res = await ProductSearchService.instance.searchStore(
      widget.store,
      q,
      limit: 60,
      categoryFilter: _selectedCategory,
      enableFuzzy: _fuzzy,
      boostPopularity: _popBoost,
    );
    if (!mounted || seq != _searchSeq) return;
    if (res.isEmpty &&
        !_fuzzy &&
        ExperimentService.instance.autoFuzzyEnabled() &&
        q.trim().length > 2) {
      final fuzzyRes = await ProductSearchService.instance.searchStore(
        widget.store,
        q,
        limit: 60,
        categoryFilter: _selectedCategory,
        enableFuzzy: true,
        boostPopularity: _popBoost,
        useCache: false,
      );
      if (!mounted || seq != _searchSeq) return;
      if (fuzzyRes.isNotEmpty) {
        res = fuzzyRes;
        _autoFuzzyApplied = true;
      }
    }
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (!mounted) return;

    var filtered = _applyPostFilters(res);
    // Pre-compute personalization scores (cached) once per search.
    // Build brand cache early for sorting/filter performance.
    final bc = <String, String>{};
    for (final p in res) {
      try {
        bc[p.id] = ProductSearchService.instance.inferredBrand(widget.store, p);
      } catch (_) {}
    }
    _brandCache = bc;
    final prodScores = <String, double>{};
    double maxScore = 0;
    final toCheck = filtered.take(140).toList(); // modest cap
    // Launch parallel fetches for scores not cached yet.
    final futures = <Future>[];
    for (final p in toCheck) {
      if (_productScoreCache.containsKey(p.id)) continue;
      futures.add(() async {
        try {
          final s = await PersonalizationService.instance.productScore(
            widget.store,
            p.id,
          );
          if (s > 0) _productScoreCache[p.id] = s;
        } catch (_) {}
      }());
    }
    if (futures.isNotEmpty) await Future.wait(futures);
    if (seq != _searchSeq) return; // stale search; abandon heavy UI update
    for (final p in toCheck) {
      final s = _productScoreCache[p.id];
      if (s != null && s > 0) {
        prodScores[p.id] = s;
        if (s > maxScore) maxScore = s;
      }
    }
    // Hero picks
    List<Product> hero = const [];
    try {
      final topIds = await PersonalizationService.instance.topProducts(
        widget.store,
        limit: 20,
      );
      if (topIds.isNotEmpty) {
        final idSet = topIds.toSet();
        hero = filtered.where((p) => idSet.contains(p.id)).toList()
          ..sort(
            (a, b) => topIds.indexOf(a.id).compareTo(topIds.indexOf(b.id)),
          );
        if (hero.length < 3) hero = const [];
      }
    } catch (_) {}
    // If dismissal expired, allow hero to show again.
    if (_heroDismissed && hero.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_heroKey());
        if (raw != null) {
          final ts = int.tryParse(raw);
          if (ts != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(ts);
            if (DateTime.now().difference(dt).inHours >= _heroDismissHours) {
              _heroDismissed = false; // safe local flip before setState
            }
          }
        }
      } catch (_) {}
    }
    final groupScores = await _computeGroupScores(
      filtered,
      scoreCache: prodScores,
    );
    if (!mounted) return;
    if (seq != _searchSeq) return; // superseded by a newer search
    setState(() {
      _results = filtered;
      _topPicks = hero;
      _groupScores = groupScores;
      _productScores = prodScores;
      _maxProductScore = maxScore;
      _loading = false;
      _initial = false;
      final term = q.trim();
      if (term.isNotEmpty) {
        _recent.remove(term);
        _recent.insert(0, term);
        if (_recent.length > 5) _recent.removeLast();
        _persistRecent();
      }
    });
    SearchTelemetry.instance.logSearch(
      query: q.trim(),
      store: widget.store,
      resultCount: res.length,
      fuzzy: _fuzzy || _autoFuzzyApplied,
      category: _selectedCategory,
      durationMs: elapsed,
      variant: _variant,
      popBoost: _popBoost,
      multipackOnly: _multipackOnly,
      autoFuzzy: _autoFuzzyApplied,
      normalizedQuery: q.trim().toLowerCase(),
    );
  }

  List<Product> _applyPostFilters(List<Product> input) {
    Iterable<Product> list = input;
    // Pre-compute / memo tagsLower per product for this filter run to reduce allocations.
    final Map<String, List<String>> tagCache = {};
    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      list = list.where((p) {
        final b =
            _brandCache[p.id] ??
            ProductSearchService.instance.inferredBrand(widget.store, p);
        if (!_brandCache.containsKey(p.id)) _brandCache[p.id] = b;
        return b == _selectedBrand;
      });
    }
    if (_multipackOnly)
      list = list.where(
        (p) => (p.subCategory ?? '').toLowerCase() == 'multipacks',
      );
    if (_quick.isNotEmpty) {
      list = list.where((p) {
        final tagsLower = tagCache[p.id] ??= p.tags
            .map((t) => t.toLowerCase())
            .toList();
        bool pass = true;
        for (final f in _quick) {
          switch (f) {
            case 'popular':
              pass &= (p.rating ?? 0) >= 4.6 || tagsLower.contains('popular');
              break;
            case 'new':
              pass &=
                  tagsLower.contains('new') || tagsLower.contains('limited');
              break;
            case 'value':
              final cheap = widget.store.toLowerCase() == 'taco bell'
                  ? 3.50
                  : 5.00;
              pass &=
                  tagsLower.contains('value') ||
                  tagsLower.contains('deal') ||
                  ((p.price ?? 9999) <= cheap);
              break;
            case 'personal':
              if (_productScores.isEmpty || _maxProductScore <= 0)
                pass = false;
              else {
                final s = _productScores[p.id] ?? 0;
                pass &= s >= 0.35 * _maxProductScore;
              }
              break;
          }
          if (!pass) break;
        }
        return pass;
      });
    }
    final out = list.toList();
    switch (_sort) {
      case 'name_az':
        out.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_za':
        out.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'price_low_high':
        out.sort((a, b) => (a.price ?? 1e9).compareTo(b.price ?? 1e9));
        break;
      case 'price_high_low':
        out.sort((a, b) => (b.price ?? -1).compareTo(a.price ?? -1));
        break;
      case 'brand_az':
        out.sort((a, b) {
          final ba =
              _brandCache[a.id] ??
              ProductSearchService.instance.inferredBrand(widget.store, a);
          final bb =
              _brandCache[b.id] ??
              ProductSearchService.instance.inferredBrand(widget.store, b);
          if (!_brandCache.containsKey(a.id)) _brandCache[a.id] = ba;
          if (!_brandCache.containsKey(b.id)) _brandCache[b.id] = bb;
          return ba.compareTo(bb);
        });
        break;
      case 'brand_za':
        out.sort((a, b) {
          final ba =
              _brandCache[a.id] ??
              ProductSearchService.instance.inferredBrand(widget.store, a);
          final bb =
              _brandCache[b.id] ??
              ProductSearchService.instance.inferredBrand(widget.store, b);
          if (!_brandCache.containsKey(a.id)) _brandCache[a.id] = ba;
          if (!_brandCache.containsKey(b.id)) _brandCache[b.id] = bb;
          return bb.compareTo(ba);
        });
        break;
      default:
        break;
    }
    return out;
  }

  Future<Map<String, double>> _computeGroupScores(
    List<Product> list, {
    Map<String, double>? scoreCache,
  }) async {
    final buckets = <String, List<Product>>{};
    for (final p in list) {
      final key = (p.subCategory ?? '').trim().isEmpty
          ? 'Other'
          : p.subCategory!.trim();
      final bucket = buckets.putIfAbsent(key, () => []);
      if (bucket.length < 12) bucket.add(p);
    }
    final scores = <String, double>{};
    for (final entry in buckets.entries) {
      double sum = 0;
      int count = 0;
      for (final p in entry.value) {
        double s;
        if (scoreCache != null && scoreCache.containsKey(p.id)) {
          s = scoreCache[p.id]!;
        } else {
          s = await PersonalizationService.instance.productScore(
            widget.store,
            p.id,
          );
          if (scoreCache != null && s > 0) scoreCache[p.id] = s; // warm cache
        }
        if (s > 0) {
          sum += s;
          count++;
        }
      }
      if (count > 0) scores[entry.key] = sum / count;
    }
    return scores;
  }

  List<_Group> _group(List<Product> list, {Set<String>? exclude}) {
    final map = <String, List<Product>>{};
    for (final p in list) {
      if (exclude != null && exclude.contains(p.id)) continue;
      final key = (p.subCategory ?? '').trim().isEmpty
          ? 'Other'
          : p.subCategory!.trim();
      map.putIfAbsent(key, () => []).add(p);
    }
    var groups = map.entries.map((e) => _Group(e.key, e.value)).toList();
    final firstIndex = <String, int>{};
    for (final g in groups) {
      firstIndex[g.title] = list.indexOf(g.items.first);
    }
    if (_groupScores.isNotEmpty && _groupScores.values.any((s) => s > 0)) {
      groups.sort((a, b) {
        final sa = _groupScores[a.title] ?? 0;
        final sb = _groupScores[b.title] ?? 0;
        if (sa == sb)
          return firstIndex[a.title]!.compareTo(firstIndex[b.title]!);
        return sb.compareTo(sa);
      });
    } else {
      groups.sort(
        (a, b) => firstIndex[a.title]!.compareTo(firstIndex[b.title]!),
      );
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final tacoBellSimple =
        widget.store == 'taco_bell' && _initial && _controller.text.isEmpty;
    final pandaSimple =
        widget.store == 'panda_express' && _initial && _controller.text.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus:
              !(tacoBellSimple ||
                  pandaSimple), // don't pop keyboard on category home
          decoration: const InputDecoration(
            hintText: 'Search',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onChanged: _schedule,
          onSubmitted: (v) {
            final q = v.trim();
            if (q.isNotEmpty) _runSearch(q);
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _controller.clear();
                  _results = const [];
                  _initial = true;
                });
              },
            ),
        ],
      ),
      body: tacoBellSimple
          ? _tacoBellCategoryGrid()
          : (pandaSimple
                ? _pandaCategoryGrid()
                : Column(
                    children: [
                      if (_initial && widget.store != 'taco_bell') _brandHero(),
                      _sortBar(),
                      _categoryChips(),
                      _brandChips(),
                      if (_results.isNotEmpty) _quickChips(),
                      Expanded(child: _resultsArea()),
                    ],
                  )),
      floatingActionButton: (!tacoBellSimple && _showToTop)
          ? FloatingActionButton.small(
              onPressed: () {
                _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Icon(Icons.arrow_upward),
              tooltip: 'Top',
            )
          : null,
    );
  }

  Widget _pandaCategoryGrid() {
    if (_pandaCats.isEmpty && _pandaCatsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pandaCats.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadPandaExpressCategories,
          icon: const Icon(Icons.refresh),
          label: const Text('Reload Categories'),
        ),
      );
    }
    final branding = StoreBranding.of(widget.store);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      itemCount: _pandaCats.length,
      itemBuilder: (_, i) {
        final c = _pandaCats[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (widget.store == 'panda_express') {
                final lower = c.label.toLowerCase();
                if (lower == 'bowls') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductDetailScreen(
                        id: 'panda_express_bowl_bowls',
                        name: 'Bowl',
                        description: 'Bowl • Choose 1 Base and 1 Entrée',
                        price: 8.50,
                        unit: '1 bowl',
                      ),
                    ),
                  );
                  return;
                }
                if (lower == 'plates') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductDetailScreen(
                        id: 'panda_express_plate_plates',
                        name: 'Plate',
                        description: 'Plate • Choose 1 Base and 2 Entrées',
                        price: 10.50,
                        unit: '1 plate',
                      ),
                    ),
                  );
                  return;
                }
                if (lower == 'bigger plate' ||
                    lower == 'bigger plate'.toLowerCase() ||
                    lower == 'bigger plates') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductDetailScreen(
                        id: 'panda_express_bigger_plate',
                        name: 'Bigger Plate',
                        description:
                            'Bigger Plate • Choose 1 Base and 3 Entrées',
                        price: 12.40,
                        unit: '1 plate',
                      ),
                    ),
                  );
                  return;
                }
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductListScreen(
                    category: c.label,
                    title: c.label,
                    fileOverrides: [c.file],
                  ),
                ),
              );
            },
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF1E1E1E),
                border: Border.all(
                  color: branding.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: SizedBox(
                height: 88,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(17),
                        ),
                        child: c.imageUrl.isNotEmpty
                            ? _CategoryImage(
                                url: c.imageUrl,
                                branding: branding,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: branding.gradient,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.rice_bowl,
                                  size: 34,
                                  color: Colors.white70,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          c.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.15,
                            letterSpacing: .2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _resultsArea() {
    if (_initial) {
      return _initialSuggestions();
    }
    if (_loading) {
      return CustomScrollView(
        slivers: [
          _skHeader('Loading'),
          _skGrid(),
          _skHeader('More'),
          _skGrid(),
        ],
      );
    }
    if (_results.isEmpty) return _emptyState();
    final heroIds = _topPicks.map((p) => p.id).toSet();
    final groups = _group(_results, exclude: heroIds);
    final showHero = _topPicks.isNotEmpty && !_heroDismissed;
    final useGrouping = groups.length > 1;
    for (int i = 0; i < groups.length; i++) {
      final g = groups[i];
      _expanded.putIfAbsent(g.title, () => i < 2 || g.items.length <= 6);
    }
    if (!useGrouping && !showHero) {
      return GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.70,
        ),
        itemCount: _results.length,
        itemBuilder: (c, i) {
          final p = _results[i];
          return _card(p, i + 1);
        },
      );
    }
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        if (_autoFuzzyApplied)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.6),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Showing fuzzy suggestions',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutQuart,
            switchOutCurve: Curves.easeInQuad,
            transitionBuilder: (child, anim) {
              return SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            child: showHero
                ? KeyedSubtree(key: const ValueKey('hero'), child: _heroStrip())
                : const SizedBox.shrink(),
          ),
        ),
        if (useGrouping) SliverToBoxAdapter(child: _groupControls(groups)),
        for (final g in groups) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _Header(
              g.title,
              count: g.items.length,
              expanded: _expanded[g.title],
              onToggle: () {
                setState(() {
                  _expanded[g.title] = !(_expanded[g.title] ?? true);
                });
                final expanded = _expanded[g.title] ?? true;
                final visible = expanded
                    ? g.items.length
                    : (g.items.length > 4 ? 4 : g.items.length);
                SearchTelemetry.instance.logGroupToggle(
                  group: g.title,
                  expanded: expanded,
                  total: g.items.length,
                  visible: visible,
                  store: widget.store,
                );
              },
            ),
          ),
          SliverToBoxAdapter(child: _groupGrid(g)),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _groupGrid(_Group g) {
    final expanded = _expanded[g.title] ?? true;
    const maxCollapsed = 4;
    final collapsed = !expanded;
    final showTile = collapsed && g.items.length > maxCollapsed;
    final items = expanded ? g.items : g.items.take(maxCollapsed).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.70,
        ),
        itemCount: items.length + (showTile ? 1 : 0),
        itemBuilder: (c, i) {
          if (showTile && i == items.length) {
            final remaining = g.items.length - items.length;
            return _ShowAllTile(
              remaining: remaining,
              onTap: () {
                setState(() => _expanded[g.title] = true);
                SearchTelemetry.instance.logGroupToggle(
                  group: g.title,
                  expanded: true,
                  total: g.items.length,
                  visible: g.items.length,
                  store: widget.store,
                );
              },
            );
          }
          final p = items[i];
          final globalRank = _results.indexOf(p) + 1;
          return _card(p, globalRank);
        },
      ),
    );
  }

  Widget _sortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sort,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'relevance',
                    child: Text('Relevance'),
                  ),
                  DropdownMenuItem(value: 'name_az', child: Text('Name A-Z')),
                  DropdownMenuItem(value: 'name_za', child: Text('Name Z-A')),
                  DropdownMenuItem(
                    value: 'price_low_high',
                    child: Text('Price Low-High'),
                  ),
                  DropdownMenuItem(
                    value: 'price_high_low',
                    child: Text('Price High-Low'),
                  ),
                  DropdownMenuItem(value: 'brand_az', child: Text('Brand A-Z')),
                  DropdownMenuItem(value: 'brand_za', child: Text('Brand Z-A')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _sort = v);
                  setState(() => _results = _applyPostFilters(_results));
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setString(_sortKey(), _sort);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _fuzzy ? 'Fuzzy On' : 'Fuzzy Off',
            icon: Icon(_fuzzy ? Icons.auto_fix_high : Icons.auto_fix_off),
            onPressed: () {
              setState(() => _fuzzy = !_fuzzy);
              if (_controller.text.trim().isNotEmpty)
                _runSearch(_controller.text);
            },
          ),
        ],
      ),
    );
  }

  Widget _initialSuggestions() {
    if (_recent.isEmpty && _categories.isEmpty) {
      return const Center(child: Text('Start typing to search'));
    }
    final chips = <Widget>[];
    if (_recent.isNotEmpty) {
      chips.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Recent', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
      chips.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recent.map((r) => _suggestChip(r, recent: true)).toList(),
        ),
      );
    }
    if (_categories.isNotEmpty) {
      chips.add(
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            'Top Categories',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      chips.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.take(12).map((c) => _suggestChip(c)).toList(),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: chips,
      ),
    );
  }

  Widget _brandHero() {
    final branding = StoreBranding.of(widget.store);
    // Show top 6 categories quickly tappable.
    final cats = _categories.take(6).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(gradient: branding.gradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'store_logo_${widget.store}',
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Image.asset(
                      'assets/restaurant_logos/${_logoBase(widget.store)}_logo.png',
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.restaurant,
                        color: branding.primary,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.store.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cravings delivered fast',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  ActionChip(
                    backgroundColor: Colors.black.withValues(alpha: 0.25),
                    label: Text(c, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      _controller.text = c;
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: c.length),
                      );
                      _runSearch(c);
                    },
                  ),
                if (_categories.length > cats.length)
                  ActionChip(
                    backgroundColor: Colors.black.withValues(alpha: 0.25),
                    label: const Text('More', style: TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _initial = false),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- Taco Bell simplified category home ---
  List<_TacoCat> _tacoCats = const [];
  bool _tacoCatsLoading = false;
  Future<void> _loadTacoBellCategoriesFull() async {
    if (_tacoCatsLoading) return;
    _tacoCatsLoading = true;
    try {
      final raw = await rootBundle.loadString(
        'assets/stores/taco_bell/taco_bell_categories.json',
      );
      final map = (jsonDecode(raw) as Map<String, dynamic>);
      final list = (map['parentCategories'] as List?) ?? [];
      final tcats = <_TacoCat>[];
      for (final c in list.whereType<Map>()) {
        final id = (c['id'] ?? '').toString();
        final label = (c['label'] ?? '').toString();
        final img = (c['imageUrl'] ?? '').toString();
        if (id.isEmpty || label.isEmpty) continue;
        final path = _tacoBellFileFor(id);
        if (path == null) continue; // hide categories we cannot load yet
        tcats.add(_TacoCat(id: id, label: label, imageUrl: img, file: path));
      }
      if (mounted) setState(() => _tacoCats = tcats);
    } catch (e) {
      debugPrint('[TacoBellCats] load failed: $e');
    } finally {
      _tacoCatsLoading = false;
    }
  }

  // --- Panda Express minimal category home (Bowls only for now) ---
  List<_TacoCat> _pandaCats = const [];
  bool _pandaCatsLoading = false;
  Future<void> _loadPandaExpressCategories() async {
    if (_pandaCatsLoading) return;
    _pandaCatsLoading = true;
    try {
      final raw = await rootBundle.loadString(
        'assets/stores/panda_express/panda-express-categories.json',
      );
      final map = (jsonDecode(raw) as Map<String, dynamic>);
      final list = (map['parentCategories'] as List?) ?? [];
      final cats = <_TacoCat>[];
      for (final c in list.whereType<Map>()) {
        final id = (c['id'] ?? '').toString();
        final label = (c['label'] ?? '').toString();
        final img = (c['imageUrl'] ?? '').toString();
        if (id.isEmpty || label.isEmpty) continue;
        final file = _pandaFileFor(id);
        if (file == null) continue;
        cats.add(_TacoCat(id: id, label: label, imageUrl: img, file: file));
      }
      if (mounted) setState(() => _pandaCats = cats);
    } catch (e) {
      debugPrint('[PandaCats] load failed: $e');
    } finally {
      _pandaCatsLoading = false;
    }
  }

  String? _pandaFileFor(String id) {
    const base = 'assets/stores/panda_express/';
    switch (id) {
      case 'bowls':
        return base + 'panda-express-bowls.json';
      case 'plates':
        return base + 'panda-express-plates.json';
      case 'bigger_plates':
        return base + 'panda-express-bigger-plate.json';
      case 'balanced_protein_plates':
        return base + 'panda-express-balanced-protein-plates.json';
      case 'appetizers':
        return base + 'panda-express-appetizers.json';
      case 'panda_crafted_beverages':
        return base + 'panda-express-crafted-beverages.json';
      case 'drinks':
        return base + 'panda-express-drinks.json';
      case 'panda_bundles':
        return base + 'panda-express-bundles.json';
      default:
        return null;
    }
  }

  String? _tacoBellFileFor(String id) {
    const base = 'assets/stores/taco_bell/';
    switch (id) {
      case 'best_sellers':
        return base + 'taco-bell-best-sellers.json';
      case 'new_items':
        return base + 'taco-bell-new-items.json';
      case 'cravings_value_menu':
        return base + 'taco-bell-cravings-value-menu.json';
      case 'cantina_chicken_menu':
        return base + 'taco-bell-cantina-chicken-menu.json';
      case 'combos_and_boxes':
        return base + 'taco-bell-combos.json';
      case 'tacos':
        return base + 'taco-bell-tacos.json';
      case 'burritos':
        return base + 'taco-bell-burritos.json';
      case 'specialties':
        return base + 'taco-bell-specialties.json';
      case 'sides_and_sweets':
        return base + 'taco-bell-side-and-sweets.json';
      case 'drinks':
        return base + 'taco-bell-drinks.json';
      case 'nachos':
        return base + 'taco-bell-nachos.json';
      case 'veggie_cravings':
        return base + 'taco-bell-veggie-cravings.json';
      case 'breakfast':
        return base + 'taco-bell-breakfast.json';
      // Missing assets intentionally hidden: quesadillas, bowls
      default:
        return null;
    }
  }

  Widget _tacoBellCategoryGrid() {
    if (_tacoCats.isEmpty && _tacoCatsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tacoCats.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadTacoBellCategoriesFull,
          icon: const Icon(Icons.refresh),
          label: const Text('Reload Categories'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int cross = 2;
        if (w >= 380) cross = 3;
        if (w >= 640) cross = 4;
        final aspect = 0.90; // image + label bar
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: aspect,
          ),
          itemCount: _tacoCats.length,
          itemBuilder: (_, i) => _tacoCategoryCard(_tacoCats[i]),
        );
      },
    );
  }

  Widget _tacoCategoryCard(_TacoCat c) {
    final branding = StoreBranding.of(widget.store);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductListScreen(
              category: c.label,
              title: c.label,
              fileOverrides: [c.file],
            ),
          ),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF1E1E1E),
          border: Border.all(
            color: branding.primary.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: c.imageUrl.isNotEmpty
                    ? _CategoryImage(url: c.imageUrl, branding: branding)
                    : Container(
                        decoration: BoxDecoration(gradient: branding.gradient),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.white54,
                        ),
                      ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Text(
                c.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  height: 1.15,
                  letterSpacing: .2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _logoBase(String store) {
    switch (store) {
      case 'taco_bell':
        return 'tacobell'; // filename uses collapsed form
      default:
        return store;
    }
  }

  Widget _suggestChip(String text, {bool recent = false}) => ActionChip(
    label: Text(text, style: const TextStyle(fontSize: 12)),
    avatar: Icon(recent ? Icons.history : Icons.category_outlined, size: 16),
    onPressed: () {
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
      _runSearch(text);
    },
  );

  Widget _emptyState() {
    final q = _controller.text.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              'No matches for "$q"',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (!_fuzzy)
              TextButton.icon(
                onPressed: () {
                  setState(() => _fuzzy = true);
                  _runSearch(q);
                },
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Try fuzzy search'),
              ),
            if (_recent.isNotEmpty) const SizedBox(height: 16),
            if (_recent.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recent
                    .map((r) => _suggestChip(r, recent: true))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _catChip(null, 'All'),
          for (final c in _categories) _catChip(c, c),
          const SizedBox(width: 4),
          _multipackChip(),
        ],
      ),
    );
  }

  Widget _catChip(String? value, String label) {
    final selected =
        value == _selectedCategory ||
        (value == null && _selectedCategory == null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
        selected: selected,
        selectedColor: Colors.amberAccent,
        backgroundColor: const Color(0xFF2a2a2a),
        onSelected: (_) {
          setState(() => _selectedCategory = value);
          if (value != null)
            PersonalizationService.instance.recordCategoryInteraction(
              widget.store,
              value,
            );
          if (_controller.text.trim().isNotEmpty) _runSearch(_controller.text);
        },
      ),
    );
  }

  Widget _multipackChip() {
    final selected = _multipackOnly;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(
          'Multi',
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
        selected: selected,
        selectedColor: Colors.deepOrangeAccent.shade100,
        backgroundColor: const Color(0xFF2a2a2a),
        onSelected: (_) async {
          setState(() => _multipackOnly = !_multipackOnly);
          setState(() => _results = _applyPostFilters(_results));
          final prefs = await SharedPreferences.getInstance();
          prefs.setBool(_multiKey(), _multipackOnly);
        },
      ),
    );
  }

  Widget _brandChips() {
    if (_brands.isEmpty) return const SizedBox.shrink();
    final show = _brands.take(25).toList();
    final hidden = _brands.length - show.length;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _brandChip(null, 'Brands'),
          for (final b in show) _brandChip(b, b),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ActionChip(
                label: Text('+$hidden'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('All Brands'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final b in _brands)
                                ChoiceChip(
                                  label: Text(
                                    b,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: _selectedBrand == b,
                                  onSelected: (_) {
                                    setState(() => _selectedBrand = b);
                                    setState(
                                      () => _results = _applyPostFilters(
                                        _results,
                                      ),
                                    );
                                    Navigator.pop(context);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _brandChip(String? value, String label) {
    final selected =
        value == _selectedBrand || (value == null && _selectedBrand == null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
        selected: selected,
        selectedColor: Colors.tealAccent.shade200,
        backgroundColor: const Color(0xFF2a2a2a),
        onSelected: (_) async {
          setState(() => _selectedBrand = value);
          setState(() => _results = _applyPostFilters(_results));
          final prefs = await SharedPreferences.getInstance();
          if (_selectedBrand == null)
            prefs.remove(_brandKey());
          else
            prefs.setString(_brandKey(), _selectedBrand!);
        },
      ),
    );
  }

  Widget _quickChips() {
    if (_results.isEmpty) return const SizedBox.shrink();
    const defs = [
      ('popular', Icons.trending_up, 'Popular'),
      ('new', Icons.fiber_new, 'New'),
      ('value', Icons.local_offer, 'Value'),
      ('personal', Icons.bolt, 'For You'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [for (final d in defs) _quickChip(d)],
      ),
    );
  }

  Widget _quickChip((String, IconData, String) def) {
    final (key, icon, label) = def;
    final selected = _quick.contains(key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (selected) {
              _quick.remove(key);
            } else {
              _quick.add(key);
            }
            _results = _applyPostFilters(_results);
          });
          SearchTelemetry.instance.logQuickFilter(
            key: key,
            enabled: !selected,
            store: widget.store,
          );
          // Persist quick filter state
          SharedPreferences.getInstance().then(
            (p) => p.setStringList(_quickKey(), _quick.toList()),
          );
        },
        selectedColor: Colors.blueAccent.withValues(alpha: 0.35),
        backgroundColor: const Color(0xFF2a2a2a),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? Colors.blueAccent.withValues(alpha: 0.8)
                : Colors.white24,
            width: 1,
          ),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _card(Product p, int rank) {
    final tagsLower = p.tags.map((t) => t.toLowerCase()).toList();
    final isNew = tagsLower.contains('new') || tagsLower.contains('limited');
    final isValue = tagsLower.contains('value') || tagsLower.contains('deal');
    final isPopular = (p.rating ?? 0) >= 4.6 || tagsLower.contains('popular');
    final isPersonal = _topPicks.any((tp) => tp.id == p.id);
    final delayMs = 40 * (rank % 8);
    return TweenAnimationBuilder<double>(
      key: ValueKey(p.id + '_$rank'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(scale: 0.95 + 0.05 * v, child: child),
      ),
      child: ProductCardV2(
        product: p,
        highlight: _controller.text,
        meta: ProductBadgeMeta(
          isNew: isNew,
          isValue: isValue,
          isPopular: isPopular,
          isPersonal: isPersonal && !isNew && !isValue && !isPopular,
        ),
        onTap: () {
          SearchTelemetry.instance.logClick(
            query: _controller.text.trim(),
            store: widget.store,
            productId: p.id,
            rank: rank,
            fuzzy: _fuzzy || _autoFuzzyApplied,
            variant: _variant,
            popBoost: _popBoost,
          );
          PersonalizationService.instance.recordProductClick(
            widget.store,
            p.id,
          );
        },
      ),
    );
  }

  Widget _heroStrip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Top Picks For You',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Hide',
                  onPressed: () async {
                    setState(() => _heroDismissed = true);
                    final prefs = await SharedPreferences.getInstance();
                    prefs.setString(
                      _heroKey(),
                      DateTime.now().millisecondsSinceEpoch.toString(),
                    );
                    SearchTelemetry.instance.logHeroDismiss(
                      count: _topPicks.length,
                      store: widget.store,
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            height: 230,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _topPicks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) {
                final p = _topPicks[i];
                final rank = _results.indexOf(p) + 1;
                return SizedBox(width: 180, child: _card(p, rank));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupControls(List<_Group> groups) {
    if (groups.length < 2) return const SizedBox.shrink();
    final allExpanded = groups.every((g) => _expanded[g.title] ?? true);
    final anyCollapsed = groups.any((g) => !(_expanded[g.title] ?? true));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Text('Groups', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          if (!allExpanded)
            TextButton(
              onPressed: () => setState(() {
                for (final g in groups) {
                  _expanded[g.title] = true;
                }
              }),
              child: const Text('Expand All'),
            ),
          if (anyCollapsed || allExpanded)
            TextButton(
              onPressed: () => setState(() {
                for (final g in groups) {
                  _expanded[g.title] = false;
                }
              }),
              child: const Text('Collapse All'),
            ),
        ],
      ),
    );
  }

  // Skeletons
  Widget _skCard() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF262626),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Expanded(
          child: ShimmerBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ShimmerBox(
            width: double.infinity,
            height: 12,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              ShimmerBox(
                width: 48,
                height: 14,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(width: 8),
              ShimmerBox(
                width: 40,
                height: 10,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  SliverPersistentHeader _skHeader(String t) =>
      SliverPersistentHeader(pinned: true, delegate: _Header(t, shimmer: true));
  SliverGrid _skGrid({int count = 4}) => SliverGrid(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.70,
    ),
    delegate: SliverChildBuilderDelegate(
      (c, i) => _skCard(),
      childCount: count,
    ),
  );
}

class _Group {
  final String title;
  final List<Product> items;
  _Group(this.title, this.items);
}

class _Header extends SliverPersistentHeaderDelegate {
  final String title;
  final bool shimmer;
  final int? count;
  final bool? expanded;
  final VoidCallback? onToggle;
  _Header(
    this.title, {
    this.shimmer = false,
    this.count,
    this.expanded,
    this.onToggle,
  });
  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final elevate = overlapsContent || shrinkOffset > 0;
    final base = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 40,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: elevate
            ? [
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : const [],
        border: const Border(
          bottom: BorderSide(color: Colors.black54, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count!.toString(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (expanded != null)
            IconButton(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(),
              icon: Icon(
                expanded! ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
              onPressed: onToggle,
              tooltip: expanded! ? 'Collapse' : 'Expand',
            ),
        ],
      ),
    );
    return shimmer ? Opacity(opacity: 0.5, child: base) : base;
  }

  @override
  bool shouldRebuild(covariant _Header old) =>
      old.title != title ||
      old.shimmer != shimmer ||
      old.count != count ||
      old.expanded != expanded;
}

class _ShowAllTile extends StatelessWidget {
  final int remaining;
  final VoidCallback onTap;
  const _ShowAllTile({required this.remaining, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.unfold_more, size: 32),
            const SizedBox(height: 12),
            Text(
              'Show all\n+$remaining',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// Taco Bell simplified category model (top-level so state class can reference it)
class _TacoCat {
  final String id;
  final String label;
  final String imageUrl;
  final String file; // product json
  const _TacoCat({
    required this.id,
    required this.label,
    required this.imageUrl,
    required this.file,
  });
}

// Reusable network image with loading + fade + error handling for Taco Bell categories
class _CategoryImage extends StatefulWidget {
  final String url;
  final StoreBranding branding;
  const _CategoryImage({required this.url, required this.branding});
  @override
  State<_CategoryImage> createState() => _CategoryImageState();
}

class _CategoryImageState extends State<_CategoryImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0,
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient (gives brand color while loading / on error)
        Container(
          decoration: BoxDecoration(gradient: widget.branding.gradient),
        ),
        Image.network(
          widget.url,
          fit: BoxFit.cover,
          frameBuilder: (_, child, frame, __) {
            if (frame != null && _fade.status == AnimationStatus.dismissed) {
              _fade.forward();
            }
            return FadeTransition(opacity: _fade, child: child);
          },
          loadingBuilder: (_, child, prog) {
            if (prog == null) return child;
            final total = prog.expectedTotalBytes;
            double? pct;
            if (total != null && total > 0) {
              pct = prog.cumulativeBytesLoaded / total;
            }
            return Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  value: pct,
                  color: Colors.white70,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            debugPrint('[CategoryImage] FAILED url=${widget.url}');
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.broken_image, size: 42, color: Colors.white70),
                  SizedBox(height: 4),
                  Text(
                    'Image',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
