import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/product.dart';

/// Generalized in-memory product catalog loaded from bundled JSON asset files.
/// Scans all files under assets/stores/** matching pattern:
///   assets/stores/<store>/*.json (excluding *_categories, .bak backups, and non-list JSON).
/// Supports partitioned files named <base>-partN.json; order-insensitive aggregation while
/// ensuring each product id is only loaded once (first occurrence wins).
class ProductCatalogService {
  ProductCatalogService._();
  static final ProductCatalogService instance = ProductCatalogService._();

  bool _loading = false;
  bool _loadedOnce = false;
  final Map<String, Product> _byId = {};
  final Map<String, List<Product>> _variantsById =
      {}; // product id -> sibling variants (excluding self)

  /// Optional cached mapping: base file -> loaded part count
  final Map<String, int> _partitionPartCounts = {};
  final Set<String> _generatedIds =
      {}; // track generated synthetic ids to avoid collisions
  Map<String, dynamic>? _modifierTemplates; // loaded from _modifier_sets.json

  // Deterministic slug (lowercase, alnum + hyphen) for stable id generation.
  String _slug(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final collapsed = cleaned.replaceAll(RegExp(r'-{2,}'), '-');
    final trimmed = collapsed.trim();
    // Remove leading hyphens and collapse again to be safe.
    final noLead = trimmed.replaceAll(RegExp(r'^-+'), '');
    return noLead.replaceAll(RegExp(r'-{2,}'), '-');
  }

  // Generate a stable synthetic id using store + slug + short hash tail.
  String _generateId({required String store, required String name}) {
    final slugged = _slug(name);
    final baseSlug = slugged.length > 40 ? slugged.substring(0, 40) : slugged;
    final hash = name.hashCode & 0x7fffffff; // positive
    String candidate =
        '${store.toLowerCase()}_auto_${baseSlug}_' + hash.toRadixString(36);
    int dedupe = 1;
    while (_byId.containsKey(candidate) || _generatedIds.contains(candidate)) {
      candidate =
          '${store.toLowerCase()}_auto_${baseSlug}_' +
          hash.toRadixString(36) +
          '_$dedupe';
      dedupe++;
    }
    _generatedIds.add(candidate);
    return candidate;
  }

  // Normalize a raw JSON map into a Product, generating missing fields when possible.
  Product? _normalizeAndBuild(Map<String, dynamic> item) {
    // Name required for any useful product
    final rawName = (item['name'] ?? '').toString().trim();
    if (rawName.isEmpty) return null;

    // Determine store id / code.
    final store = (item['storeId'] ?? item['store'] ?? 'walmart').toString();

    // Image normalization: support 'image' legacy key.
    item['imageUrl'] ??= item['image'];

    // Pass through concise unit if present; no transformation needed here.

    // Price normalization: parse numeric from string if necessary.
    final priceVal = item['price'];
    if (priceVal is String) {
      final match = RegExp(r'(\d+[\.,]?\d*)').firstMatch(priceVal);
      if (match != null) {
        final numStr = match.group(1)!.replaceAll(',', '');
        final parsed = double.tryParse(numStr);
        if (parsed != null) item['price'] = parsed;
      }
    }

    // Ensure ID.
    final existingId = (item['id'] ?? '').toString().trim();
    if (existingId.isEmpty) {
      item['id'] = _generateId(store: store, name: rawName);
    }

    // Insert normalized keys expected by Product.fromJson
    item['store'] = store; // ensure unified store field

    // Expand modifierRefs if present (template groups).
    try {
      if (item.containsKey('modifierRefs')) {
        final refs =
            (item['modifierRefs'] as List?)?.cast<String>() ?? const [];
        if (refs.isNotEmpty) {
          final templates = _modifierTemplates ?? const <String, dynamic>{};
          final expanded = <Map<String, dynamic>>[];
          for (final r in refs) {
            final tmpl = templates[r];
            if (tmpl is Map<String, dynamic>) {
              expanded.add(Map<String, dynamic>.from(tmpl));
            }
          }
          // Merge inline modifiers (for overrides / additions)
          if (item['modifiers'] is List) {
            for (final m in (item['modifiers'] as List)) {
              if (m is Map<String, dynamic>) {
                final id = m['id'];
                final idx = expanded.indexWhere((g) => g['id'] == id);
                if (idx >= 0)
                  expanded[idx] = m;
                else
                  expanded.add(m);
              }
            }
          }
          item['modifiers'] = expanded;
        }
      }
    } catch (_) {
      /* ignore expansion errors */
    }

    // Automatic Taco Bell website-style augmentation: if an entree already has
    // an included ingredients group but is missing Add Ons / Sauces groups,
    // append template-based groups so UI mirrors official site without
    // needing to edit every JSON file to add modifierRefs. Skips drinks,
    // sides/sweets, combos to avoid clutter where website doesn't show them.
    try {
      final storeLower = store.toLowerCase();
      if (storeLower == 'taco_bell' && item['modifiers'] is List) {
        final mods = (item['modifiers'] as List).cast<Map?>();
        final hasIncluded = mods.any(
          (m) => (m?['id'] == 'included_ingredients'),
        );
        final hasAddOns = mods.any((m) => (m?['id'] == 'add_ons'));
        final hasSauces = mods.any((m) => (m?['id'] == 'sauces'));
        if (hasIncluded && (!hasAddOns || !hasSauces)) {
          final category = (item['category'] ?? '').toString();
          final categoryLower = category.toLowerCase();
          final excluded =
              categoryLower.contains('drink') ||
              categoryLower.contains('side') ||
              categoryLower.contains('sweet') ||
              categoryLower.contains('combo');
          if (!excluded && _modifierTemplates != null) {
            final templates = _modifierTemplates!;
            Map<String, dynamic>? cloneTmpl(String key) {
              final t = templates[key];
              if (t is Map<String, dynamic>) {
                // Shallow clone + ensure no default:true flags (we want optional only)
                final cloned =
                    json.decode(json.encode(t)) as Map<String, dynamic>;
                if (cloned['options'] is List) {
                  for (final opt in (cloned['options'] as List)) {
                    if (opt is Map && opt['default'] == true)
                      opt.remove('default');
                  }
                }
                return cloned;
              }
              return null;
            }

            if (!hasAddOns) {
              final addOns = cloneTmpl('add_ons');
              if (addOns != null) mods.add(addOns);
            }
            if (!hasSauces) {
              final sauces = cloneTmpl('sauces');
              if (sauces != null) mods.add(sauces);
            }
            // Enforce consistent website-style ordering.
            final orderedIds = <String, int>{
              'included_ingredients': 0,
              'make_it_your_own': 1,
              'add_ons': 2,
              'sauces': 3,
            };
            final finalMods = mods.whereType<Map<String, dynamic>>().toList();
            finalMods.sort((a, b) {
              final ai = orderedIds[a['id']] ?? 999;
              final bi = orderedIds[b['id']] ?? 999;
              final cmp = ai.compareTo(bi);
              if (cmp != 0) return cmp;
              // Stable fallback by name to keep deterministic order for "other" groups
              return (a['name'] ?? '').toString().compareTo(
                (b['name'] ?? '').toString(),
              );
            });
            item['modifiers'] = finalMods;
          }
        }
      }
    } catch (_) {
      /* ignore augmentation errors */
    }
    return Product.fromJson(item);
  }

  Future<void> ensureLoaded() async {
    if (_loading) return; // prevent re-entrancy
    _loading = true;
    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestRaw);
      // Load modifier template sets early so expansion works during product normalization.
      try {
        const tmplPath = 'assets/stores/taco_bell/_modifier_sets.json';
        if (manifest.containsKey(tmplPath)) {
          final tmplRaw = await rootBundle.loadString(tmplPath);
          final parsed = json.decode(tmplRaw);
          if (parsed is Map<String, dynamic>) {
            _modifierTemplates = parsed;
          }
        }
      } catch (_) {
        /* ignore template load errors */
      }
      final productFiles = manifest.keys.where((p) {
        if (!p.startsWith('assets/stores/')) return false;
        if (!p.endsWith('.json')) return false;
        if (p.contains('_categories')) return false;
        if (p.endsWith('.json.bak')) return false; // ignore backups
        return true;
      }).toList()..sort();

      // Group partition files by base (strip -partN)
      final Map<String, List<String>> grouped = {};
      for (final path in productFiles) {
        final fileName = path.split('/').last;
        final base = fileName.contains('-part')
            ? fileName.replaceFirst(RegExp(r'-part\d+\.json'), '.json')
            : fileName;
        grouped.putIfAbsent(base, () => []).add(path);
      }

      for (final entry in grouped.entries) {
        final base = entry.key;
        final paths = entry.value..sort();
        int loadedParts = 0;
        for (final path in paths) {
          try {
            final raw = await rootBundle.loadString(path);
            final decoded = json.decode(raw);
            if (decoded is! List) continue; // skip non-list JSON
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                final product = _normalizeAndBuild(item);
                if (product == null) continue;
                if (_byId.containsKey(product.id)) {
                  final existing = _byId[product.id]!;
                  final newHasNotes = product.fragranceProfile?.topNotes.isNotEmpty == true ||
                      product.fragranceProfile?.heartNotes.isNotEmpty == true;
                  final existingHasNotes = existing.fragranceProfile?.topNotes.isNotEmpty == true ||
                      existing.fragranceProfile?.heartNotes.isNotEmpty == true;
                  if (newHasNotes && !existingHasNotes) {
                    _byId[product.id] = product;
                  }
                  continue;
                }
                _byId[product.id] = product;
              }
            }
            if (paths.length > 1 && path.contains('-part')) loadedParts++;
          } catch (e) {
            // ignore: avoid_print
            print('[Catalog] Failed to load $path: $e');
          }
        }
        if (loadedParts > 0) {
          _partitionPartCounts[base] = loadedParts;
        }
      }
      _buildVariantIndex();
    } catch (e) {
      // ignore: avoid_print
      print('[Catalog] Manifest parse failed: $e');
    } finally {
      _loading = false;
      _loadedOnce = true;
    }
  }

  // Build variant groups across all stores: products sharing same base stem (name w/o size/pack tokens)
  // and same brand (if brand present) OR same store when brand absent.
  void _buildVariantIndex() {
    _variantsById.clear();
    final Map<String, List<Product>> groups = {};
    for (final p in _byId.values) {
      final stem = _baseStem(p.name);
      final brand = (p.brand ?? '').trim().toLowerCase();
      final store = (p.store ?? '').trim().toLowerCase();
      final key = (brand.isNotEmpty ? 'b:$brand:' : 's:$store:') + stem;
      groups.putIfAbsent(key, () => []).add(p);
    }
    for (final entry in groups.entries) {
      final list = entry.value;
      if (list.length <= 1) continue; // need at least 2 to be variants
      // Sort for stable order by variant sort key then name
      list.sort((a, b) {
        final sk = _variantSortKey(a.name).compareTo(_variantSortKey(b.name));
        if (sk != 0) return sk;
        return a.name.compareTo(b.name);
      });
      for (final p in list) {
        _variantsById[p.id] = list.where((o) => o.id != p.id).toList();
      }
    }
  }

  String _baseStem(String name) {
    var n = name.toLowerCase();
    // Remove pack count e.g. 12 pack, 24 ct, 20 count
    n = n.replaceAll(RegExp(r'\b\d+\s?(?:pack|ct|count)\b'), '');
    // Remove composite size patterns like 12 x 12 fl oz
    n = n.replaceAll(
      RegExp(r'\b\d+\s?[xX]\s?\d+(?:\.\d+)?\s?(?:fl\s?oz|oz|ml|l|g|lb)\b'),
      '',
    );
    // Remove single size / weight tokens
    n = n.replaceAll(
      RegExp(r'\b\d+(?:\.\d+)?\s?(?:fl\s?oz|oz|ml|l|g|lb)\b'),
      '',
    );
    // Remove container words that vary with size
    n = n.replaceAll(
      RegExp(
        r'\b(bottle|bottles|can|cans|pack|packs|carton|cartons|pouch|pouches)\b',
      ),
      '',
    );
    n = n.replaceAll(RegExp(r'[,:]'), ' ');
    n = n.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return n;
  }

  double _variantSortKey(String name) {
    // Prefer pack count numeric
    final pack = RegExp(
      r'(\d+)\s?(?:pack|ct|count)',
      caseSensitive: false,
    ).firstMatch(name);
    if (pack != null) return double.tryParse(pack.group(1)!) ?? 0;
    // Multi pattern 12 x 12 fl oz -> pack count * each size as tie-breaker scale
    final multi = RegExp(
      r'(\d+)\s?[xX]\s?(\d+(?:\.\d+)?)\s?(fl\s?oz|oz|ml|l)',
      caseSensitive: false,
    ).firstMatch(name);
    if (multi != null) {
      final c = double.tryParse(multi.group(1)!) ?? 0;
      final each = _toBaseUnit(multi.group(2)!, multi.group(3)!);
      return c + each / 1000; // slight increment to keep ordering
    }
    // Single size
    final size = RegExp(
      r'(\d+(?:\.\d+)?)\s?(fl\s?oz|oz|ml|l|g|lb)',
      caseSensitive: false,
    ).firstMatch(name);
    if (size != null) return _toBaseUnit(size.group(1)!, size.group(2)!);
    return 0;
  }

  double _toBaseUnit(String numStr, String unitRaw) {
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

  List<Product> variantsFor(String id) => _variantsById[id] ?? const [];

  Product? get(String id) => _byId[id];
  Iterable<Product> all() => _byId.values;
  bool get isLoaded => _loadedOnce;
  int get count => _byId.length;
  Map<String, int> get partitionPartCounts =>
      Map.unmodifiable(_partitionPartCounts);
}
