import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Lightweight related products engine.
/// Loads all store product JSON assets (currently Aldi subset) into memory
/// and provides top-N related suggestions based on:
///  - Same subCategory (weight 3)
///  - Name keyword overlap (weight 1 per shared token)
///  - Brand token match (weight 2)
///  - Price band proximity (within 15% => +1)
class RelatedProductsService {
  RelatedProductsService._();
  static final instance = RelatedProductsService._();

  bool _loaded = false;
  final Map<String, Map<String, dynamic>> _byId = {};
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    // For now, load only Aldi product JSON files (pattern aldi_*.json excluding categories file)
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifest);
    final aldiFiles = manifestMap.keys.where(
      (p) =>
          p.startsWith('assets/stores/aldi/aldi_') &&
          p.endsWith('.json') &&
          !p.contains('_categories'),
    );
    for (final path in aldiFiles) {
      try {
        final raw = await rootBundle.loadString(path);
        final List data = json.decode(raw);
        for (final item in data) {
          if (item is Map) {
            final id = item['id']?.toString();
            if (id != null) {
              _byId[id] = item.cast<String, dynamic>();
            }
          }
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  List<Map<String, dynamic>> relatedFor(String productId, {int limit = 8}) {
    if (_cache.containsKey(productId)) return _cache[productId]!;
    final base = _byId[productId];
    if (base == null) return const [];
    final baseNameTokens = _tokens(base['name']);
    final baseBrandTokens = _tokens(base['brand']);
    final baseSub = (base['subCategory'] ?? '').toString();
    final basePrice = (base['price'] is num)
        ? (base['price'] as num).toDouble()
        : null;

    final List<(double score, Map<String, dynamic> prod)> scored = [];
    for (final entry in _byId.entries) {
      if (entry.key == productId) continue;
      final p = entry.value;
      double score = 0;
      if ((p['subCategory'] ?? '') == baseSub) score += 3;
      final nameTokens = _tokens(p['name']);
      final overlap = nameTokens.intersection(baseNameTokens).length;
      score += overlap.toDouble();
      final brandTokens = _tokens(p['brand']);
      if (brandTokens.isNotEmpty &&
          brandTokens.intersection(baseBrandTokens).isNotEmpty) {
        score += 2;
      }
      if (basePrice != null && p['price'] is num) {
        final price = (p['price'] as num).toDouble();
        final diff = (price - basePrice).abs();
        if (diff / basePrice <= 0.15) score += 1; // within 15%
      }
      if (score > 0) scored.add((score, p));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final result = scored.take(limit).map((e) => e.$2).toList();
    _cache[productId] = result;
    return result;
  }

  Set<String> _tokens(dynamic raw) {
    if (raw == null) return {};
    final s = raw.toString().toLowerCase();
    final cleaned = s.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ');
    final parts = cleaned
        .split(RegExp(r'\s+'))
        .where((e) => e.length > 2)
        .toSet();
    return parts;
  }
}
