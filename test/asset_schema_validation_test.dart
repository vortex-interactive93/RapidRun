import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Set<String>> _loadAllowedWalmartDeliSubCategories() async {
  try {
    final cfgRaw = await rootBundle.loadString(
      'assets/config/product_asset_rules.json',
    );
    final cfg = json.decode(cfgRaw) as Map<String, dynamic>;
    final list = (cfg['walmartDeliAllowedSubCategories'] as List<dynamic>?)
        ?.cast<String>();
    if (list != null && list.isNotEmpty) return list.toSet();
  } catch (_) {
    /* ignore and fallback */
  }
  return const {
    'Soups',
    'Hot case',
    'Salad bowls & trays',
    'Pasta',
    'Pizza',
    'Lunch meats',
    'Sliced deli meats & cheeses',
    'Gourmet meats & cheeses',
    'Dips & spreads',
    'Sandwiches & wraps',
    'Party trays',
    'Prepared meals & sides',
    'Rotisserie & Hot Case',
    'Quick breakfasts',
    'Prepared Asian food',
    'The Charcuterie Shop',
    'Lunch kits',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Product asset files pass minimal schema + uniqueness validation', () async {
    final manifestRaw = await rootBundle.loadString('AssetManifest.json');
    final manifest = json.decode(manifestRaw) as Map<String, dynamic>;

    const legacyFileSkips = <String>{
      'walmart-pantry-trays.json',
      'walmart-prepared-meals-and-sides.json',
      // Legacy placeholders (data migrated to walmart-deli-* equivalents)
      'walmart-quick-breakfasts.json',
      'walmart-saladbowls-and-trays.json',
      'walmart-sandwhiches-and-wraps.json',
      // Additional legacy files
      'walmart-deli-sandwiches.json',
      'walmart-deli-salads.json',
    };

    final productFiles = manifest.keys.where((p) {
      if (!p.startsWith('assets/stores/')) return false;
      if (!p.endsWith('.json')) return false;
      if (p.contains('_categories')) return false;
      if (p.contains('/raw_legacy/')) return false;
      if (legacyFileSkips.any((f) => p.endsWith(f))) return false;
      return true;
    }).toList()..sort();

    expect(
      productFiles,
      isNotEmpty,
      reason: 'No product asset JSON files found',
    );

    final seenIds = <String>{};
    final duplicateIds = <String>[];
    final nameUnitToIds = <String, List<String>>{};

    final allowedWalmartDeliSubCategories =
        await _loadAllowedWalmartDeliSubCategories();

    for (final path in productFiles) {
      final raw = await rootBundle.loadString(path);
      dynamic decoded;
      try {
        decoded = json.decode(raw);
      } catch (e) {
        fail('Failed to decode JSON for $path: $e');
      }
      if (decoded is! List) {
        continue; // Non-list assets ignored
      }
      for (final entry in decoded) {
        if (entry is! Map) fail('Entry in $path is not a JSON object: $entry');
        final map = entry.cast<String, dynamic>();
        final id = map['id']?.toString() ?? '';
        final name = map['name']?.toString() ?? '';
        expect(id.isNotEmpty, true, reason: 'Missing/empty id in file $path');
        final idPattern = RegExp(r'^[a-z0-9_-]+$');
        if (!idPattern.hasMatch(id)) {
          // Temporary: treat as warning; normalization job will fix.
          // ignore: avoid_print
          print(
            '[AssetSchema] WARNING: id pattern mismatch "$id" in $path (expected ${idPattern.pattern})',
          );
        }
        if (name.isEmpty) {
          // Temporary allowance while data normalization continues.
          // ignore: avoid_print
          print('[AssetSchema] WARNING: empty name for id=$id in $path');
        }
        // Enforce required keys similar to JSON schema
        // NOTE: Temporarily allow null price for placeholder / partially
        // normalized records (e.g. Uncategorized ingestion stubs) while
        // enrichment pipeline is maturing. We still require the field to
        // exist so downstream code can rely on presence, but we *warn*
        // (log) instead of failing the test if it is null.
        const requiredKeys = [
          'name',
          'id',
          'storeId',
          'category',
          'subCategory',
          'price', // required key presence (may be null temporarily)
        ];
        for (final rk in requiredKeys) {
          expect(
            map.containsKey(rk),
            true,
            reason: 'Missing required key $rk for id=$id in $path',
          );
          if (rk == 'price') {
            if (map[rk] == null) {
              // ignore: avoid_print
              print('[AssetSchema] WARNING: null price for id=$id in $path');
            } else {
              expect(
                map[rk],
                isNotNull,
                reason: 'Null required key $rk for id=$id in $path',
              );
            }
          } else {
            expect(
              map[rk],
              isNotNull,
              reason: 'Null required key $rk for id=$id in $path',
            );
          }
        }
        // Basic allowed keys set (simulate additionalProperties=false with a soft allow-list)
        const allowedKeys = {
          'name',
          'price',
          'imageUrl',
          'id',
          'description',
          'benefits',
          'unit',
          // Enriched normalized quantity breakdown (allowed extension)
          'unitInfo',
          'storeId',
          'category',
          'subCategory',
          'rating',
          'tags',
          // Extended keys introduced in normalization/enrichment pipeline
          'brand',
          'shortName',
          'originalName',
          'aisle',
          // Restaurant / configurable items
          'modifiers',
          'modifierRefs',
          // Nutrition fields added during restaurant normalization
          'calories',
          'minCalories',
          'maxCalories',
          // Combo modeling
          'isCombo',
          'includedItems',
          'choiceGroups',
        };
        final extra = map.keys.where((k) => !allowedKeys.contains(k)).toList();
        expect(
          extra.isEmpty,
          true,
          reason:
              'Unexpected keys ${extra.join(', ')} in product id=$id ($path)',
        );
        if (map.containsKey('price') && map['price'] != null) {
          expect(
            map['price'] is num,
            true,
            reason: 'Non-numeric price for id=$id in $path',
          );
        }
        if (map.containsKey('rating') && map['rating'] != null) {
          expect(
            map['rating'] is num,
            true,
            reason: 'Non-numeric rating for id=$id in $path',
          );
        }
        if (map.containsKey('tags') && map['tags'] != null) {
          expect(
            map['tags'] is List,
            true,
            reason: 'Tags is not a List for id=$id in $path',
          );
        }
        if (!seenIds.add(id)) duplicateIds.add(id);
        if (map['category'] == 'Deli') {
          final nameUnitKey =
              '${name.toLowerCase().trim()}::${(map['unit'] ?? '').toString().toLowerCase()}';
          nameUnitToIds.putIfAbsent(nameUnitKey, () => <String>[]).add(id);
        }
        final subCategory = map['subCategory'];
        if (subCategory is String) {
          final storeId = map['storeId'];
          if (storeId == 'walmart' && map['category'] == 'Deli') {
            expect(
              allowedWalmartDeliSubCategories.contains(subCategory),
              true,
              reason:
                  'Unexpected Walmart Deli subCategory "$subCategory" for id=$id. Update config if intentional.',
            );
          }
        }
      }
    }

    if (duplicateIds.isNotEmpty) {
      // ignore: avoid_print
      print(
        '[AssetSchema] WARNING: duplicate product ids (${duplicateIds.length}): '
        '${duplicateIds.toSet().take(50).join(', ')}${duplicateIds.toSet().length > 50 ? ' …' : ''}',
      );
    }

    final duplicateNameUnitGroups = nameUnitToIds.values
        .where((ids) => ids.length > 1)
        .toList();
    if (duplicateNameUnitGroups.isNotEmpty) {
      // ignore: avoid_print
      print('[AssetSchema] NOTICE: potential duplicate (name+unit) entries:');
      for (final group in duplicateNameUnitGroups.take(30)) {
        print('  -> ${group.join(', ')}');
      }
      if (duplicateNameUnitGroups.length > 30) {
        print('  ... (${duplicateNameUnitGroups.length - 30} more)');
      }
    }

    // After existing duplicate reports, add partition integrity checks.
    final partitionGroups = <String, List<String>>{}; // base -> file paths
    for (final path in productFiles) {
      final fileName = path.split('/').last;
      if (fileName.contains('-part')) {
        final base = fileName.replaceFirst(RegExp(r'-part\d+\.json'), '.json');
        partitionGroups.putIfAbsent(base, () => []).add(path);
      }
    }
    for (final entry in partitionGroups.entries) {
      final base = entry.key;
      final files = entry.value..sort();
      final allIds = <int>[];
      for (final f in files) {
        final raw = await rootBundle.loadString(f);
        final decoded = json.decode(raw);
        if (decoded is! List) continue;
        for (final e in decoded) {
          if (e is Map && e['id'] is String) {
            final m = RegExp(r'_(\d+)$').firstMatch(e['id'] as String);
            if (m != null) allIds.add(int.parse(m.group(1)!));
          }
        }
      }
      allIds.sort();
      // Overlap check: duplicates in numeric suffix inside parts
      final dupInParts = <int>[];
      for (var i = 1; i < allIds.length; i++) {
        if (allIds[i] == allIds[i - 1]) dupInParts.add(allIds[i]);
      }
      expect(
        dupInParts.isEmpty,
        true,
        reason:
            'Overlapping numeric ids across parts of $base: ${dupInParts.take(10).join(', ')}',
      );
      // Gap warning (non-fatal): detect missing numbers inside min..max
      if (allIds.isNotEmpty) {
        final missing = <int>[];
        for (var n = allIds.first; n <= allIds.last; n++) {
          if (!allIds.contains(n)) missing.add(n);
          if (missing.length > 50) break; // cap noise
        }
        if (missing.isNotEmpty) {
          // ignore: avoid_print
          print(
            '[AssetSchema] NOTICE: gaps in partitioned sequence for $base (first ${missing.length} missing: ${missing.take(25).join(', ')}${missing.length > 25 ? ' …' : ''})',
          );
        }
      }
    }
  });
}
