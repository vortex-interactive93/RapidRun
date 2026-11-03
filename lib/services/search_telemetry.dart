import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Lightweight in-memory telemetry for search usage.
class SearchTelemetry {
  SearchTelemetry._();
  static final instance = SearchTelemetry._();

  static const int _maxEvents = 500;
  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  bool _loaded = false;
  static const _prefsKey = 'search_telemetry_events';

  UnmodifiableListView<Map<String, dynamic>> get events =>
      UnmodifiableListView(_events);

  /// Public hook to guarantee events loaded before reading aggregates.
  Future<void> ensureLoaded() async => _ensureLoaded();

  void logSearch({
    required String query,
    required String store,
    required int resultCount,
    required bool fuzzy,
    String? category,
    required int durationMs,
    String? variant, // experiment variant (e.g., 'A' | 'B')
    bool? popBoost, // whether popularity boost applied for this search
    bool? multipackOnly, // new: true if user filtered to only multipacks
    bool? autoFuzzy, // auto-fuzzy fallback triggered
    String? normalizedQuery, // optional normalized (e.g., singularized) form
  }) {
    _ensureLoaded();
    final evt = {
      'type': 'search',
      'q': query,
      'store': store.toLowerCase(),
      'results': resultCount,
      'fuzzy': fuzzy,
      'cat': category,
      'ms': durationMs,
      't': DateTime.now().millisecondsSinceEpoch,
      if (variant != null) 'var': variant,
      if (popBoost != null) 'pop': popBoost ? 1 : 0,
      if (multipackOnly == true) 'mp': 1,
      if (autoFuzzy == true) 'af': 1,
      if (normalizedQuery != null && normalizedQuery != query)
        'nq': normalizedQuery,
    };
    _add(evt);
  }

  void logClick({
    required String query,
    required String store,
    required String productId,
    required int rank,
    required bool fuzzy,
    String? variant,
    bool? popBoost,
  }) {
    _ensureLoaded();
    final evt = {
      'type': 'click',
      'q': query,
      'store': store.toLowerCase(),
      'pid': productId,
      'rank': rank,
      'fuzzy': fuzzy,
      't': DateTime.now().millisecondsSinceEpoch,
      if (variant != null) 'var': variant,
      if (popBoost != null) 'pop': popBoost ? 1 : 0,
    };
    _add(evt);
  }

  void logQuickFilter({
    required String key,
    required bool enabled,
    required String store,
  }) {
    _ensureLoaded();
    _add({
      'type': 'qfilter',
      'key': key,
      'en': enabled ? 1 : 0,
      'store': store.toLowerCase(),
      't': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void logGroupToggle({
    required String group,
    required bool expanded,
    required int total,
    required int visible,
    required String store,
  }) {
    _ensureLoaded();
    _add({
      'type': 'gtoggle',
      'g': group,
      'ex': expanded ? 1 : 0,
      'n': total,
      'vis': visible,
      'store': store.toLowerCase(),
      't': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void logHeroDismiss({required int count, required String store}) {
    _ensureLoaded();
    _add({
      'type': 'herodismiss',
      'c': count,
      'store': store.toLowerCase(),
      't': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Returns a map of productId -> popularity score (time-decayed click weight) for a store.
  /// Newer clicks weigh more using exponential decay. Designed for lightweight in-memory ranking.
  Future<Map<String, double>> productPopularityScores(
    String store, {
    Duration halfLife = const Duration(hours: 12),
  }) async {
    await ensureLoaded();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final decay = halfLife.inMilliseconds;
    if (decay <= 0) return const {};
    final scores = <String, double>{};
    for (final e in _events) {
      if (e['type'] != 'click') continue;
      if (e['store'] != store.toLowerCase()) continue;
      final pid = e['pid'] as String?;
      if (pid == null) continue;
      final t = (e['t'] as int?) ?? nowMs;
      final ageMs = (nowMs - t).clamp(0, 1000 * 60 * 60 * 24 * 30); // cap 30d
      // Exponential decay: weight = 0.5 ^ (age/halfLife)
      final weight = MathHelper.exp2(-(ageMs / decay));
      scores.update(pid, (v) => v + weight, ifAbsent: () => weight);
    }
    return scores;
  }

  Map<String, dynamic> summary() {
    int searches = 0;
    int clicks = 0;
    int zeroResults = 0;
    int totalResultsReturned = 0;
    int cumulativeLatency = 0;
    int searchesWithClicks = 0;
    int clickRankSum = 0;
    int clicksTop1 = 0;
    int clicksTop3 = 0;
    int mpSearches = 0;
    int mpClicks = 0;
    int autoFuzzySearches = 0;
    final Map<String, bool> queryStoreClick = {};
    for (final e in _events) {
      if (e['type'] == 'search') {
        searches++;
        totalResultsReturned += (e['results'] as int? ?? 0);
        if ((e['results'] as int? ?? 0) == 0) zeroResults++;
        cumulativeLatency += (e['ms'] as int? ?? 0);
        final key = '${e['q']}::${e['store']}';
        queryStoreClick.putIfAbsent(key, () => false);
        if (e['mp'] == 1) mpSearches++;
        if (e['af'] == 1) autoFuzzySearches++;
      } else if (e['type'] == 'click') {
        clicks++;
        final key = '${e['q']}::${e['store']}';
        queryStoreClick[key] = true;
        final rank = (e['rank'] as int?) ?? 0;
        if (rank > 0) {
          clickRankSum += rank;
          if (rank == 1) clicksTop1++;
          if (rank <= 3) clicksTop3++;
        }
        if (e['mp'] == 1) mpClicks++;
      }
    }
    searchesWithClicks = queryStoreClick.values.where((v) => v).length;
    final avgResults = searches == 0 ? 0 : totalResultsReturned / searches;
    final avgLatency = searches == 0 ? 0 : cumulativeLatency / searches;
    final ctr = searches == 0 ? 0 : clicks / searches;
    final clickSearchRate = searches == 0 ? 0 : searchesWithClicks / searches;
    final avgClickRank = clicks == 0 ? 0 : clickRankSum / clicks;
    final pctClicksTop1 = clicks == 0 ? 0 : clicksTop1 / clicks;
    final pctClicksTop3 = clicks == 0 ? 0 : clicksTop3 / clicks;
    final mpCtr = mpSearches == 0 ? 0 : mpClicks / mpSearches;
    return {
      'searches': searches,
      'clicks': clicks,
      'zeroResults': zeroResults,
      'avgResults': avgResults,
      'avgLatencyMs': avgLatency,
      'clicksPerSearch': ctr,
      'searchesWithClicksRate': clickSearchRate,
      'avgClickRank': avgClickRank,
      'pctClicksTop1': pctClicksTop1,
      'pctClicksTop3': pctClicksTop3,
      'mpSearches': mpSearches,
      'mpClicks': mpClicks,
      'mpClicksPerSearch': mpCtr,
      'autoFuzzySearches': autoFuzzySearches,
    };
  }

  /// Returns top zero-result queries (case-insensitive aggregated) with counts.
  List<Map<String, dynamic>> zeroResultQueriesTop(int n) {
    final counts = <String, int>{};
    for (final e in _events) {
      if (e['type'] == 'search' && (e['results'] as int? ?? 0) == 0) {
        final q = (e['q'] as String).trim().toLowerCase();
        if (q.isEmpty) continue;
        counts[q] = (counts[q] ?? 0) + 1;
      }
    }
    final list = counts.entries
        .map((e) => {'query': e.key, 'count': e.value})
        .toList();
    list.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    if (list.length > n) return list.take(n).toList();
    return list;
  }

  /// Returns aggregated metrics grouped by experiment variant (key = variant string).
  Map<String, Map<String, dynamic>> experimentVariantSummary() {
    final Map<String, List<Map<String, dynamic>>> byVar = {};
    for (final e in _events) {
      final v = e['var'];
      if (v is String && v.isNotEmpty) {
        byVar.putIfAbsent(v, () => []).add(e);
      }
    }
    final Map<String, Map<String, dynamic>> out = {};
    for (final entry in byVar.entries) {
      final base = _aggregate(entry.value);
      // Add auto-fuzzy searches count within this variant for deeper analysis.
      final afCount = entry.value
          .where((e) => e['type'] == 'search' && e['af'] == 1)
          .length;
      base['autoFuzzySearches'] = afCount;
      // Variant-level zero-result rate when auto-fuzzy applied vs not applied.
      final zeroWithAF = entry.value
          .where(
            (e) =>
                e['type'] == 'search' &&
                e['af'] == 1 &&
                (e['results'] as int? ?? 0) == 0,
          )
          .length;
      final zeroWithoutAF = entry.value
          .where(
            (e) =>
                e['type'] == 'search' &&
                e['af'] != 1 &&
                (e['results'] as int? ?? 0) == 0,
          )
          .length;
      base['zeroResultsWithAF'] = zeroWithAF;
      base['zeroResultsWithoutAF'] = zeroWithoutAF;
      out[entry.key] = base;
    }
    return out;
  }

  Map<String, dynamic> _aggregate(List<Map<String, dynamic>> events) {
    int searches = 0;
    int clicks = 0;
    int zeroResults = 0;
    int totalResultsReturned = 0;
    int cumulativeLatency = 0;
    int searchesWithClicks = 0;
    int clickRankSum = 0;
    int clicksTop1 = 0;
    int clicksTop3 = 0;
    final Map<String, bool> queryStoreClick = {};
    for (final e in events) {
      if (e['type'] == 'search') {
        searches++;
        totalResultsReturned += (e['results'] as int? ?? 0);
        if ((e['results'] as int? ?? 0) == 0) zeroResults++;
        cumulativeLatency += (e['ms'] as int? ?? 0);
        final key = '${e['q']}::${e['store']}';
        queryStoreClick.putIfAbsent(key, () => false);
      } else if (e['type'] == 'click') {
        clicks++;
        final key = '${e['q']}::${e['store']}';
        queryStoreClick[key] = true;
        final rank = (e['rank'] as int?) ?? 0;
        if (rank > 0) {
          clickRankSum += rank;
          if (rank == 1) clicksTop1++;
          if (rank <= 3) clicksTop3++;
        }
      }
    }
    searchesWithClicks = queryStoreClick.values.where((v) => v).length;
    final avgResults = searches == 0 ? 0 : totalResultsReturned / searches;
    final avgLatency = searches == 0 ? 0 : cumulativeLatency / searches;
    final ctr = searches == 0 ? 0 : clicks / searches;
    final clickSearchRate = searches == 0 ? 0 : searchesWithClicks / searches;
    final avgClickRank = clicks == 0 ? 0 : clickRankSum / clicks;
    final pctClicksTop1 = clicks == 0 ? 0 : clicksTop1 / clicks;
    final pctClicksTop3 = clicks == 0 ? 0 : clicksTop3 / clicks;
    return {
      'searches': searches,
      'clicks': clicks,
      'zeroResults': zeroResults,
      'avgResults': avgResults,
      'avgLatencyMs': avgLatency,
      'clicksPerSearch': ctr,
      'searchesWithClicksRate': clickSearchRate,
      'avgClickRank': avgClickRank,
      'pctClicksTop1': pctClicksTop1,
      'pctClicksTop3': pctClicksTop3,
    };
  }

  void _add(Map<String, dynamic> evt) {
    _events.add(evt);
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    dev.log(
      'SearchTelemetry: ${evt['type']} ${evt['q']}',
      name: 'SearchTelemetry',
    );
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Store as compact JSON list
      await prefs.setString(_prefsKey, json.encode(_events));
    } catch (_) {}
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true; // prevent reentry
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map<String, dynamic>) {
              _events.add(e);
            }
          }
        }
      }
      if (_events.length > _maxEvents) {
        _events.removeRange(0, _events.length - _maxEvents);
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    _events.clear();
    await _persist();
  }

  String exportJson() => json.encode(_events);

  /// Writes current telemetry events to an application documents directory file
  /// named telemetry_YYYYMMDD_HHMMSS.json and returns the full path.
  /// Returns null if writing fails.
  Future<String?> exportToFile() async {
    try {
      await ensureLoaded();
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final name =
          'telemetry_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
      final file = File('${dir.path}/$name');
      await file.writeAsString(exportJson());
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

/// Local math helpers (avoid pulling in dart:math directly where we only need fast exponent base2)
class MathHelper {
  static double exp2(num x) => math.exp(0.6931471805599453 * x);
  static double ln(num x) => math.log(x);
}
