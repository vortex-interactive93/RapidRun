import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight client-side personalization for store category & product ranking.
/// Tracks interaction events with time decay and exposes ordered recommendations.
class PersonalizationService {
  PersonalizationService._();
  static final instance = PersonalizationService._();

  static const _prefsKey = 'personalization_store_v1';
  static const _version = 1; // bump for schema changes

  Map<String, _StorePersonalization> _byStore = {}; // storeId -> data
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        final ver = decoded['v'] as int? ?? 0;
        if (ver == _version) {
          final stores = decoded['stores'] as Map<String, dynamic>?;
          if (stores != null) {
            _byStore = stores.map(
              (k, v) => MapEntry(
                k,
                _StorePersonalization.fromJson(v as Map<String, dynamic>),
              ),
            );
          }
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = json.encode({
      'v': _version,
      'stores': _byStore.map((k, v) => MapEntry(k, v.toJson())),
    });
    await prefs.setString(_prefsKey, payload);
  }

  /// Record a category view (chip tap, hero exposure, etc.)
  Future<void> recordCategoryInteraction(
    String store,
    String categoryId,
  ) async {
    await ensureLoaded();
    final s = _byStore.putIfAbsent(store, () => _StorePersonalization());
    s.bumpCategory(categoryId);
    _schedulePersist();
  }

  /// Record a product click.
  Future<void> recordProductClick(String store, String productId) async {
    await ensureLoaded();
    final s = _byStore.putIfAbsent(store, () => _StorePersonalization());
    s.bumpProduct(productId);
    _schedulePersist();
  }

  /// Returns categories sorted by descending score; unknown categories appended.
  Future<List<String>> rankedCategories(
    String store,
    List<String> allCats,
  ) async {
    await ensureLoaded();
    final s = _byStore[store];
    if (s == null) return allCats; // nothing yet
    final scored = <String, double>{};
    for (final c in allCats) {
      scored[c] = s.categoryScore(c);
    }
    allCats.sort((a, b) => scored[b]!.compareTo(scored[a]!));
    return allCats;
  }

  /// Top N product ids for a store; used for recommendations.
  Future<List<String>> topProducts(String store, {int limit = 10}) async {
    await ensureLoaded();
    final s = _byStore[store];
    if (s == null) return const [];
    final entries = s.products.entries.toList()
      ..sort((a, b) => b.value.score.compareTo(a.value.score));
    return entries.take(limit).map((e) => e.key).toList();
  }

  /// Decayed personalization score for a single product id (0 if unknown).
  Future<double> productScore(String store, String productId) async {
    await ensureLoaded();
    final s = _byStore[store];
    if (s == null) return 0;
    final entry = s.products[productId];
    return entry?.decayedScore() ?? 0;
  }

  Timer? _persistTimer;
  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 2), _persist);
  }
}

class _StorePersonalization {
  final Map<String, _ScoreEntry> categories = {};
  final Map<String, _ScoreEntry> products = {};
  // 12 hour half-life in ms
  static const int _halfLifeMs = 12 * 60 * 60 * 1000;
  static const _categoryWeight = 1.0;
  static const _productWeight = 2.5; // product clicks weigh more

  void bumpCategory(String id) {
    final e = categories.putIfAbsent(id, () => _ScoreEntry());
    e.applyImpulse(_categoryWeight);
  }

  void bumpProduct(String id) {
    final e = products.putIfAbsent(id, () => _ScoreEntry());
    e.applyImpulse(_productWeight);
  }

  double categoryScore(String id) => categories[id]?.decayedScore() ?? 0;

  Map<String, dynamic> toJson() => {
    'c': categories.map((k, v) => MapEntry(k, v.toJson())),
    'p': products.map((k, v) => MapEntry(k, v.toJson())),
  };
  static _StorePersonalization fromJson(Map<String, dynamic> json) {
    final s = _StorePersonalization();
    final c = json['c'] as Map<String, dynamic>?;
    final p = json['p'] as Map<String, dynamic>?;
    if (c != null) {
      for (final entry in c.entries) {
        s.categories[entry.key] = _ScoreEntry.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    if (p != null) {
      for (final entry in p.entries) {
        s.products[entry.key] = _ScoreEntry.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    return s;
  }
}

class _ScoreEntry {
  double score = 0; // accumulated score
  int lastUpdated = DateTime.now().millisecondsSinceEpoch;

  void applyImpulse(double weight) {
    // Apply decay before adding new weight
    score = decayedScore();
    score += weight;
    lastUpdated = DateTime.now().millisecondsSinceEpoch;
  }

  double decayedScore() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - lastUpdated;
    const halfLife = _StorePersonalization._halfLifeMs;
    if (age <= 0) return score;
    // score * (0.5)^(age/halfLife)
    final decayFactor = math.pow(0.5, age / halfLife);
    return score * (decayFactor as double);
  }

  Map<String, dynamic> toJson() => {'s': score, 't': lastUpdated};
  static _ScoreEntry fromJson(Map<String, dynamic> json) {
    final e = _ScoreEntry();
    e.score = (json['s'] as num?)?.toDouble() ?? 0;
    e.lastUpdated =
        (json['t'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    return e;
  }
}
