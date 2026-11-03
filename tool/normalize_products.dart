import 'dart:convert';
import 'dart:io';

/*
Universal product normalizer across store data folders.
Features:
  - Supports multiple stores (walmart, aldi, target, bath_and_body_works) via --store or all.
  - Reads each store's category mapping file (<store>_categories.json) to derive category & subCategory.
  - Normalizes disparate JSON product entries into canonical schema:
      { id, name, brand, price, imageUrl, description, benefits, unit, storeId, category, subCategory }
  - Detects existing normalized items (has id + numeric price) and preserves IDs unless --reassign provided.
  - Assigns new sequential IDs continuing the highest existing numeric suffix per store (prefix configurable).
  - Brand parsing heuristic + optional curated list.
  - Unit extraction (oz, fl oz, g, ml, lb, ct, count).
  - Price parsing from free-form strings (e.g. "current price Now $5.97").
  - Dry-run mode (--dry-run) to preview changes without writing.
  - Optional --id-prefix to override default store-based prefix.
  - Skips config/mapping/backup files & already normalized variant files unless --force.

Usage examples:
  dart run tool/normalize_products.dart --store=walmart --dry-run
  dart run tool/normalize_products.dart --store=all
  dart run tool/normalize_products.dart --store=aldi --id-prefix=aldi_prod_

Extensibility hooks noted with TODO comments.
*/

const supportedStores = <String>{
  'walmart',
  'aldi',
  'target',
  'bath_and_body_works',
};

Future<void> main(List<String> args) async {
  final argMap = _parseArgs(args);
  final dryRun = argMap.containsKey('dry-run');
  final targetStore = argMap['store'] ?? 'all';
  final force = argMap.containsKey('force');
  final reassign = argMap.containsKey('reassign');
  final customPrefix = argMap['id-prefix'];
  final statsOutPath = argMap['stats-out'];
  final exportItemsPath = argMap['export-items'];
  final exportFormat = (argMap['export-format'] ?? 'json').toLowerCase();
  final exportFieldsRaw =
      argMap['export-fields']; // comma-separated list for CSV / JSON pruning
  final diffAgainstPath = argMap['diff-against'];
  final diffOutPath = argMap['diff-out'];
  final streamJsonOut = argMap['stream-json-out'];
  if (exportItemsPath != null &&
      !{'json', 'ndjson', 'csv'}.contains(exportFormat)) {
    stderr.writeln('Unsupported --export-format (use json, ndjson, or csv)');
    exit(2);
  }
  final exportFields = exportFieldsRaw == null
      ? null
      : exportFieldsRaw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

  // Load external configuration (brands, stop words, keyword category map)
  await _loadNormalizerConfig();

  final stores = targetStore == 'all'
      ? supportedStores
      : supportedStores.where((s) => s == targetStore).toSet();
  if (stores.isEmpty) {
    stderr.writeln('No valid store selected.');
    exit(2);
  }

  final aggregatedStats = <String, dynamic>{};
  final storeStats = <String, dynamic>{};
  final aggregatedItems = <Map<String, dynamic>>[];
  IOSink? ndjsonSink;
  if (exportItemsPath != null && (exportFormat == 'ndjson')) {
    ndjsonSink = File(exportItemsPath).openWrite();
  }
  IOSink? csvSink;
  if (exportItemsPath != null && exportFormat == 'csv') {
    final file = File(exportItemsPath);
    file.parent.createSync(recursive: true);
    csvSink = file.openWrite();
    // header row
    final headerFields = exportFields ?? _defaultExportFields;
    csvSink.writeln(headerFields.join(','));
  }
  // Streaming JSON sink (independent of standard export)
  IOSink? streamJsonSink;
  final _StreamState streamState = _StreamState();
  if (streamJsonOut != null) {
    final f = File(streamJsonOut);
    f.parent.createSync(recursive: true);
    streamJsonSink = f.openWrite();
    streamJsonSink.writeln('['); // will close with ']'
  }
  for (final store in stores) {
    stdout.writeln('--- Normalizing store: $store ---');
    final storeStart = DateTime.now();
    final stats = await _normalizeStore(
      store: store,
      dryRun: dryRun,
      force: force,
      reassign: reassign,
      customPrefix: customPrefix,
      exportItemsFormat: exportItemsPath == null ? null : exportFormat,
      aggregatedItems: exportItemsPath != null && exportFormat == 'json'
          ? aggregatedItems
          : null,
      ndjsonSink: ndjsonSink,
      csvSink: csvSink,
      exportFields: exportFields,
      streamJsonSink: streamJsonSink,
      streamState: streamJsonSink == null ? null : streamState,
    );
    final elapsedMs = DateTime.now().difference(storeStart).inMilliseconds;
    final items = (stats['items'] ?? 0) as int;
    stats['elapsedMs'] = elapsedMs;
    stats['itemsPerSec'] = elapsedMs == 0 ? null : (items * 1000 / elapsedMs);
    storeStats[store] = stats;
  }
  if (streamJsonSink != null) {
    streamJsonSink.writeln();
    streamJsonSink.writeln(']');
    await streamJsonSink.flush();
    await streamJsonSink.close();
    stdout.writeln('Streaming JSON export completed: $streamJsonOut');
  }

  if (statsOutPath != null) {
    aggregatedStats['generatedAt'] = DateTime.now().toUtc().toIso8601String();
    aggregatedStats['dryRun'] = dryRun;
    aggregatedStats['stores'] = storeStats;
    final outFile = File(statsOutPath);
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(aggregatedStats),
    );
    stdout.writeln('Stats written to ${outFile.path}');
  }
  if (exportItemsPath != null) {
    if (exportFormat == 'json') {
      final file = File(exportItemsPath);
      file.parent.createSync(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(aggregatedItems),
      );
      stdout.writeln(
        'Exported ${aggregatedItems.length} items to ${file.path}',
      );
    } else if (exportFormat == 'ndjson') {
      await ndjsonSink?.flush();
      await ndjsonSink?.close();
      stdout.writeln('NDJSON export completed: $exportItemsPath');
    } else if (exportFormat == 'csv') {
      await csvSink?.flush();
      await csvSink?.close();
      stdout.writeln('CSV export completed: $exportItemsPath');
    }
    // Optional diffing (only supports JSON baseline for now)
    if (diffAgainstPath != null) {
      try {
        final baselineFile = File(diffAgainstPath);
        if (baselineFile.existsSync()) {
          final baselineData = json.decode(await baselineFile.readAsString());
          if (baselineData is List && exportFormat == 'json') {
            final currentById = {
              for (final m in aggregatedItems)
                if (m['id'] != null) m['id'].toString(): m,
            };
            final baselineById = <String, Map<String, dynamic>>{};
            for (final b in baselineData) {
              if (b is Map && b['id'] != null) {
                baselineById[b['id'].toString()] = b.map(
                  (k, v) => MapEntry(k.toString(), v),
                );
              }
            }
            final newIds = <String>[];
            final removedIds = <String>[];
            final changed = <Map<String, dynamic>>[];
            for (final id in currentById.keys) {
              if (!baselineById.containsKey(id)) newIds.add(id);
            }
            for (final id in baselineById.keys) {
              if (!currentById.containsKey(id)) removedIds.add(id);
            }
            const watchedFields = [
              'name',
              'price',
              'brand',
              'category',
              'subCategory',
            ];
            for (final id in currentById.keys) {
              final cur = currentById[id]!;
              final base = baselineById[id];
              if (base == null) continue;
              final diffs = <String, dynamic>{};
              for (final f in watchedFields) {
                final a = base[f];
                final b = cur[f];
                if (a is num && b is num) {
                  if (a != b) diffs[f] = {'before': a, 'after': b};
                } else if ((a ?? '') != (b ?? '')) {
                  diffs[f] = {'before': a, 'after': b};
                }
              }
              if (diffs.isNotEmpty) {
                changed.add({'id': id, 'fields': diffs});
              }
            }
            final diffResult = {
              'baseline': diffAgainstPath,
              'currentExport': exportItemsPath,
              'newCount': newIds.length,
              'removedCount': removedIds.length,
              'changedCount': changed.length,
              'newIds': newIds,
              'removedIds': removedIds,
              'changed': changed.take(100).toList(), // limit verbosity
              'generatedAt': DateTime.now().toUtc().toIso8601String(),
            };
            if (diffOutPath != null) {
              final outFile = File(diffOutPath);
              outFile.parent.createSync(recursive: true);
              await outFile.writeAsString(
                const JsonEncoder.withIndent('  ').convert(diffResult),
              );
              stdout.writeln(
                'Diff written to ${outFile.path} (new=${newIds.length} removed=${removedIds.length} changed=${changed.length})',
              );
            } else {
              stdout.writeln(
                'Diff summary: new=${newIds.length} removed=${removedIds.length} changed=${changed.length}',
              );
            }
          } else {
            stdout.writeln(
              'Diff skipped: baseline not a JSON array or export not JSON.',
            );
          }
        } else {
          stdout.writeln('Diff baseline not found: $diffAgainstPath');
        }
      } catch (e) {
        stderr.writeln('Diff failed: $e');
      }
    }
  }
  stdout.writeln('Done${dryRun ? ' (dry-run)' : ''}.');
}

Future<Map<String, dynamic>> _normalizeStore({
  required String store,
  required bool dryRun,
  required bool force,
  required bool reassign,
  String? customPrefix,
  String? exportItemsFormat,
  List<Map<String, dynamic>>? aggregatedItems,
  IOSink? ndjsonSink,
  IOSink? csvSink,
  List<String>? exportFields,
  IOSink? streamJsonSink,
  _StreamState? streamState,
}) async {
  final storeDir = Directory('assets/stores/$store');
  if (!storeDir.existsSync()) {
    stderr.writeln('Store dir missing: ${storeDir.path}');
    return {};
  }

  final categoryMapping = await _loadCategoryMapping(store);
  // Recursively gather JSON files so nested store folders (e.g. bath_and_body_works) are processed.
  final files =
      storeDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .where((f) => !_isSkippableFile(store, f, force: force))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final idPrefix = customPrefix ?? _defaultIdPrefixForStore(store);
  var maxId = await _findMaxIdAcrossStore(store, idPrefix, recursive: true);
  int totalFiles = 0;
  int totalItems = 0;
  int newIds = 0;
  int updated = 0;
  final categoryCounts = <String, int>{};
  final subCategoryCounts = <String, int>{};
  // Validation / quality metrics
  int missingBrand = 0;
  int missingUnit = 0;
  int missingPrice = 0;
  int negativePrice = 0;
  int invalidImageUrl = 0;
  int uncategorizedInitial = 0;
  int uncategorizedAfter = 0;
  int duplicatesRemoved = 0;
  int brandNormalizedCount = 0;

  for (final file in files) {
    totalFiles++;
    List<dynamic> raw;
    try {
      raw = json.decode(await file.readAsString()) as List<dynamic>;
    } catch (e) {
      stderr.writeln('Decode failed (${file.path}): $e');
      continue;
    }

    final fileName = file.uri.pathSegments.last;
    final inferred = _inferCategory(store, fileName, categoryMapping);
    final seenSignature = <String>{};
    var changed = false;
    final normalized = <Map<String, dynamic>>[];

    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final name = (map['name'] ?? '').toString().trim();
      final imageUrl = (map['imageUrl'] ?? map['image'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty || imageUrl.isEmpty) {
        // skip incomplete
        continue;
      }
      final sig = '$name::$imageUrl';
      if (!seenSignature.add(sig)) {
        changed = true;
        duplicatesRemoved++;
        continue; // dedupe
      }

      // Existing id & price preservation logic
      String? id = map['id']?.toString();
      final numericPrice = _parsePrice(map['price']);
      if (id == null || reassign || !id.startsWith(idPrefix)) {
        maxId++;
        id = '${idPrefix}${maxId.toString().padLeft(4, '0')}';
        newIds++;
        changed = true;
      }

      // If price wasn't numeric originally, mark changed
      if (map['price'] != null && map['price'] is! num) {
        changed = true;
      }

      final unit = _extractUnit(name);
      // Derive a concise unit (drop verbose total patterns like "16x16 fl oz (total 256 fl oz)")
      String? conciseUnit;
      if (unit != null) {
        final verboseMulti =
            RegExp(r'^\d+x\d').hasMatch(unit) && unit.contains('(total');
        if (!verboseMulti) {
          conciseUnit = unit;
        } else {
          // Attempt to reduce "16x16 fl oz (total 256 fl oz)" -> "16 pk (16 fl oz)"
          final m = RegExp(
            r'^(\d+)x(\d+(?:\.\d+)?)\s*([a-z ]+)',
          ).firstMatch(unit.toLowerCase());
          if (m != null) {
            conciseUnit =
                '${m.group(1)} pk (${m.group(2)} ${m.group(3)!.trim()})';
          }
        }
      }
      final brand = _extractBrand(name);
      final brandNormalized = brand != null
          ? _brandNormalizationMap[brand] ?? brand
          : null;
      if (brand != null && brandNormalized != brand) {
        brandNormalizedCount++;
      }

      final out = {
        'id': id,
        'name': name,
        'brand': brandNormalized ?? brand,
        'price': numericPrice,
        'imageUrl': imageUrl,
        'description': map['description'],
        'benefits': map['benefits'],
        'unit': unit,
        if (conciseUnit != null) 'unitShort': conciseUnit,
        'storeId': store,
        'category': inferred.category,
        'subCategory': inferred.subCategory,
      };

      // Optional: refine Uncategorized items via keyword map
      if (out['category'] == 'Uncategorized') {
        uncategorizedInitial++;
      }
      _refineCategoryWithKeywords(out, name, store);
      if (out['category'] == 'Uncategorized') {
        uncategorizedAfter++;
      }

      if (brand == null) missingBrand++;
      if (unit == null) missingUnit++;
      if (numericPrice == null) missingPrice++;
      if (numericPrice != null && numericPrice < 0) negativePrice++;
      if (!imageUrl.startsWith('http')) invalidImageUrl++;

      // Enrichment hook (placeholder for future augmentation logic)
      _enrichItem(out);

      // Detect missing fields previously
      if (!entry.keys.contains('brand') || !entry.keys.contains('unit')) {
        changed = true;
      }

      normalized.add(out);
      if (exportItemsFormat != null) {
        if (exportItemsFormat == 'json') {
          aggregatedItems?.add(out);
        } else if (exportItemsFormat == 'ndjson') {
          ndjsonSink?.writeln(json.encode(out));
        } else if (exportItemsFormat == 'csv') {
          _writeCsvRow(csvSink, out, exportFields);
        }
      }
      // Streaming JSON (independent of export format)
      if (streamJsonSink != null && streamState != null) {
        final encoded = json.encode(out);
        if (streamState.first) {
          streamState.first = false;
          streamJsonSink.write('  ' + encoded);
        } else {
          streamJsonSink.write(',\n  ' + encoded);
        }
      }
      totalItems++;
      // Stats tallies
      categoryCounts.update(
        out['category'] ?? 'Uncategorized',
        (v) => v + 1,
        ifAbsent: () => 1,
      );
      subCategoryCounts.update(
        out['subCategory'] ?? 'Unknown',
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }

    if (!dryRun && (changed || force)) {
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(normalized),
      );
    }

    if (changed) updated++;

    if (dryRun) {
      stdout.writeln(
        '[DRY] ${fileName}: items=${normalized.length} changed=$changed',
      );
    }
  }

  stdout.writeln(
    'Store $store summary: files=$totalFiles items=$totalItems newIds=$newIds updatedFiles=$updated prefix=$idPrefix',
  );
  // Emit top category stats (sorted by descending count)
  if (categoryCounts.isNotEmpty) {
    final sortedCats = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln('Top categories:');
    for (final e in sortedCats.take(10)) {
      stdout.writeln('  ${e.key}: ${e.value}');
    }
  }
  if (subCategoryCounts.isNotEmpty) {
    final sortedSubs = subCategoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln('Top subCategories:');
    for (final e in sortedSubs.take(10)) {
      stdout.writeln('  ${e.key}: ${e.value}');
    }
  }
  return {
    'files': totalFiles,
    'items': totalItems,
    'newIds': newIds,
    'updatedFiles': updated,
    'prefix': idPrefix,
    'missingBrand': missingBrand,
    'missingUnit': missingUnit,
    'missingPrice': missingPrice,
    'negativePrice': negativePrice,
    'invalidImageUrl': invalidImageUrl,
    'duplicatesRemoved': duplicatesRemoved,
    'uncategorizedInitial': uncategorizedInitial,
    'uncategorizedAfter': uncategorizedAfter,
    'brandNormalized': brandNormalizedCount,
    'topCategories':
        (categoryCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(10)
            .map((e) => {'category': e.key, 'count': e.value})
            .toList(),
    'topSubCategories':
        (subCategoryCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(10)
            .map((e) => {'subCategory': e.key, 'count': e.value})
            .toList(),
  };
}

class _CategoryInfo {
  final String category;
  final String subCategory;
  _CategoryInfo(this.category, this.subCategory);
}

Future<Map<String, _CategoryInfo>> _loadCategoryMapping(String store) async {
  final file = File('assets/stores/$store/${store}_categories.json');
  if (!file.existsSync()) return {};
  try {
    final data = json.decode(await file.readAsString());
    if (data is! List) return {};
    final map = <String, _CategoryInfo>{};
    for (final cat in data) {
      if (cat is! Map) continue;
      final categoryName = cat['categoryName']?.toString();
      final sections = cat['sections'];
      if (categoryName == null || sections is! List) continue;
      for (final sec in sections) {
        if (sec is! Map) continue;
        final productTypes = sec['productTypes'];
        if (productTypes is! List) continue;
        for (final pt in productTypes) {
          if (pt is! Map) continue;
          final name = pt['name']?.toString();
          final filePath = pt['filePath']?.toString();
          if (name == null || filePath == null) continue;
          final fileName = filePath.split('/').last;
          map[fileName] = _CategoryInfo(categoryName, name);
        }
      }
    }
    return map;
  } catch (_) {
    return {};
  }
}

_CategoryInfo _inferCategory(
  String store,
  String fileName,
  Map<String, _CategoryInfo> mapping,
) {
  final mapped = mapping[fileName];
  if (mapped != null) return mapped;
  // Fallback: use file base name (strip extension & store prefix) as subCategory
  final base = fileName.replaceAll('.json', '');
  String cleaned = base;
  if (cleaned.startsWith('${store}_'))
    cleaned = cleaned.substring(store.length + 1);
  cleaned = cleaned.replaceAll(RegExp(r'[_-]+'), ' ');
  final title = cleaned
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return _CategoryInfo('Uncategorized', title);
}

bool _isSkippableFile(String store, File file, {required bool force}) {
  final name = file.uri.pathSegments.last;
  final segments = file.path.split(Platform.pathSeparator);
  // Skip any hidden folders (.vs, .git, etc.) in the path
  if (segments.any((s) => s.startsWith('.') && s.length > 1)) return true;
  if (name == '${store}_categories.json') return true; // mapping
  // Skip known config / meta pattern files that are not product lists
  if (name.endsWith('_config.json')) return true;
  if (name.contains('_catalog.json.meta.json')) return true;
  if (name.endsWith('.bak')) return true;
  if (name.startsWith('normalize_')) return true;
  if (name.startsWith('.')) return true;
  if (name.contains('normalized__')) return true; // previous variant splits
  if (!force && name.contains('.normalized'))
    return true; // treat pre-normalized sets as immutable
  return false;
}

Future<int> _findMaxIdAcrossStore(
  String store,
  String prefix, {
  bool recursive = false,
}) async {
  final dir = Directory('assets/stores/$store');
  if (!dir.existsSync()) return 0;
  final re = RegExp(RegExp.escape(prefix) + r'(\d{4,})');
  int maxId = 0;
  final entities = dir.listSync(recursive: recursive, followLinks: false);
  for (final entity in entities) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    try {
      final data = json.decode(await entity.readAsString());
      if (data is List) {
        for (final item in data) {
          if (item is Map && item['id'] is String) {
            final m = re.firstMatch(item['id']);
            if (m != null) {
              final v = int.tryParse(m.group(1)!);
              if (v != null && v > maxId) maxId = v;
            }
          }
        }
      }
    } catch (_) {
      // ignore parse errors
    }
  }
  return maxId;
}

String _defaultIdPrefixForStore(String store) {
  switch (store) {
    case 'walmart':
      return 'walmart_';
    case 'aldi':
      return 'aldi_';
    case 'target':
      return 'target_';
    case 'bath_and_body_works':
      return 'bbw_';
    default:
      return '${store}_';
  }
}

double? _parsePrice(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  final s = raw.toString();
  final regex = RegExp(r'(\d+[\.,]?\d*)');
  double? last;
  for (final m in regex.allMatches(s)) {
    final val = m.group(1)!.replaceAll(',', '');
    final parsed = double.tryParse(val);
    if (parsed != null) last = parsed;
  }
  return last;
}

String? _extractUnit(String name) {
  final lower = name.toLowerCase();
  final unitRegex = RegExp(
    r'(\b\d+(?:\.\d+)?\s?(?:fl\.?\s?oz|oz|g|ml|lb|lbs|count|ct|pk|pack)\b)',
  );
  final matches = unitRegex.allMatches(lower).toList();
  if (matches.isEmpty) return null;
  return matches.last.group(1);
}

// Default stop words (may be extended / overridden by config)
final _defaultGenericStopWords = <String>{
  'the',
  'and',
  'with',
  'for',
  'body',
  'wash',
  'scrub',
  'lotion',
  'cream',
  'butter',
  'shea',
  'gel',
  'soap',
  'moisturizer',
  'moisturizing',
  'ultra',
  'intensive',
  'daily',
  'women',
  'men',
  'kids',
  'all',
  'skin',
  'facial',
  'face',
  'original',
  'limited',
  'edition',
  'holiday',
  'treats',
  'exfoliating',
  'exfoliant',
  'deep',
  'clean',
  'cleanser',
  'value',
  'pack',
  'multi',
  'vitamin',
  'spray',
  'oil',
  'milk',
  'bar',
  'bubble',
  'bath',
  'salts',
  'epsom',
  'salt',
  'soak',
  'glow',
  'firming',
  'cashmere',
  'fresh',
  'cozy',
  'vanilla',
  'pink',
  'champagne',
  'peach',
  'coconut',
  'watermelon',
  'rose',
  'tropical',
  'mango',
  'cocoa',
  'coffee',
  'citrus',
  'currant',
  'amber',
  'hyaluronic',
  'acid',
  'hydrating',
  'conditioning',
  'soft',
  'softening',
};

// Default known brands (may be extended / overridden by config)
final _defaultKnownBrands = <String>{
  'Dove',
  'Tree Hut',
  'eos',
  'Suave',
  'OLLY',
  'OGX',
  'Equate',
  'Dr Teal\'s',
  'Bodycology',
  'ONYX',
  'Vaseline',
  'St. Ives',
  'Palmer\'s',
  'Neutrogena',
  'Aveeno',
  'Gold Bond',
  'Bio-Oil',
  'Jergens',
  'Cortizone 10',
  'Cicatricure',
  'Dermarest',
  'Olay',
  'Cetaphil',
  'Dial',
  'Native',
  'Irish Spring',
  'Caress',
  'Banana Boat',
  'Monistat',
  // Supplements / fitness additions
  'Premier Protein',
  'Muscle Milk',
  'RYSE',
  'CLIF',
  'FITCRUNCH',
  'LUNA',
  'Nature Valley',
  'Built',
  'Six Star',
  'Body Fortress',
  'Orgain',
  'Vital Proteins',
  'Dymatize',
};

// Effective sets loaded from config (fall back to defaults)
Set<String> _genericStopWords = {..._defaultGenericStopWords};
Set<String> _knownBrands = {..._defaultKnownBrands};
Map<String, Map<String, String>> _keywordCategoryMapGlobal = {};
Map<String, Map<String, Map<String, String>>> _keywordCategoryMapPerStore = {};
Map<String, String> _brandNormalizationMap = {};

// Default export field order for CSV (can be overridden with --export-fields)
const _defaultExportFields = [
  'id',
  'storeId',
  'category',
  'subCategory',
  'brand',
  'name',
  'price',
  'unit',
  'imageUrl',
];

String? _extractBrand(String name) {
  // Direct known brand match
  for (final b in _knownBrands) {
    if (name.toLowerCase().startsWith(b.toLowerCase())) return b;
  }
  // Heuristic: take leading capitalized tokens until a stop word / lowercase / number
  final tokens = name.split(RegExp(r'\s+'));
  final collected = <String>[];
  for (final t in tokens) {
    final plain = t.replaceAll(RegExp(r"[^A-Za-z0-9']"), '');
    if (plain.isEmpty) continue;
    final lower = plain.toLowerCase();
    final isCapitalized = plain[0].toUpperCase() == plain[0];
    final isStop = _genericStopWords.contains(lower);
    final isNumber = RegExp(r'^\d').hasMatch(plain);
    if (collected.isEmpty && isCapitalized && !isStop && !isNumber) {
      collected.add(plain);
      continue;
    }
    if (collected.isNotEmpty) {
      // allow second token if capitalized and not stop word
      if (isCapitalized && !isStop && !isNumber && collected.length < 3) {
        collected.add(plain);
        continue;
      }
      break;
    }
  }
  if (collected.isEmpty) return null;
  final candidate = collected.join(' ');
  // De-dupe repeated first token (e.g. "Optimum Optimum Nutrition" -> "Optimum Nutrition")
  final parts = candidate.split(' ');
  if (parts.length >= 2 && parts[0].toLowerCase() == parts[1].toLowerCase()) {
    parts.removeAt(0);
  }
  // Remove trailing generic marketing adjectives unlikely part of core brand
  const trailingGenerics = {
    'Gold',
    'Standard',
    'Advanced',
    'Super',
    'Ultra',
    'Premium',
    'Original',
    'Nutrition',
  };
  if (parts.length > 1 && trailingGenerics.contains(parts.last)) {
    parts.removeLast();
  }
  // Avoid generic single-word non-brands
  if (collected.length == 1 &&
      _genericStopWords.contains(collected.first.toLowerCase())) {
    return null;
  }
  return parts.join(' ');
}

void _refineCategoryWithKeywords(
  Map<String, dynamic> out,
  String name,
  String store,
) {
  if (out['category'] != 'Uncategorized') return;
  final lower = name.toLowerCase();
  // Store overrides
  final storeMap = _keywordCategoryMapPerStore[store];
  if (storeMap != null) {
    for (final entry in storeMap.entries) {
      final keyword = entry.key.toLowerCase();
      if (lower.contains(keyword)) {
        final data = entry.value;
        out['category'] = data['category'] ?? out['category'];
        out['subCategory'] = data['subCategory'] ?? out['subCategory'];
        return;
      }
    }
  }
  // Global
  for (final entry in _keywordCategoryMapGlobal.entries) {
    final keyword = entry.key.toLowerCase();
    if (lower.contains(keyword)) {
      final data = entry.value;
      out['category'] = data['category'] ?? out['category'];
      out['subCategory'] = data['subCategory'] ?? out['subCategory'];
      return;
    }
  }
}

Future<void> _loadNormalizerConfig() async {
  final file = File('tool/normalizer_config.json');
  if (!file.existsSync()) return; // silently ignore
  try {
    final data = json.decode(await file.readAsString());
    if (data is! Map) return;
    // knownBrands
    final kb = data['knownBrands'];
    if (kb is List) {
      _knownBrands = {..._defaultKnownBrands, ...kb.map((e) => e.toString())};
    }
    // genericStopWords
    final sw = data['genericStopWords'];
    if (sw is List) {
      _genericStopWords = {
        ..._defaultGenericStopWords,
        ...sw.map((e) => e.toString().toLowerCase()),
      };
    }
    // keywordCategoryMap (supports legacy flat or new structured { global, stores })
    final kw = data['keywordCategoryMap'];
    if (kw is Map) {
      if (kw.containsKey('global') || kw.containsKey('stores')) {
        final global = kw['global'];
        if (global is Map) {
          final g = <String, Map<String, String>>{};
          global.forEach((k, v) {
            if (v is Map) {
              g[k.toString()] = v.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              );
            }
          });
          _keywordCategoryMapGlobal = g;
        }
        final stores = kw['stores'];
        if (stores is Map) {
          final per = <String, Map<String, Map<String, String>>>{};
          stores.forEach((storeName, storeVal) {
            if (storeVal is Map) {
              final sm = <String, Map<String, String>>{};
              storeVal.forEach((k, v) {
                if (v is Map) {
                  sm[k.toString()] = v.map(
                    (key, value) => MapEntry(key.toString(), value.toString()),
                  );
                }
              });
              per[storeName.toString()] = sm;
            }
          });
          _keywordCategoryMapPerStore = per;
        }
      } else {
        // Legacy flat
        final g = <String, Map<String, String>>{};
        kw.forEach((k, v) {
          if (v is Map) {
            g[k.toString()] = v.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            );
          }
        });
        _keywordCategoryMapGlobal = g;
      }
    }
    // brandNormalization map
    final bn = data['brandNormalization'];
    if (bn is Map) {
      final m = <String, String>{};
      bn.forEach((k, v) {
        if (v != null) m[k.toString()] = v.toString();
      });
      _brandNormalizationMap = m;
    }
  } catch (e) {
    stderr.writeln('Failed to load normalizer_config.json: $e');
  }
}

// Placeholder enrichment hook: customize as needed
Map<String, dynamic> _enrichItem(Map<String, dynamic> item) {
  // Example: could derive pricePerUnit if both price & unit parseable, etc.
  return item;
}

void _writeCsvRow(
  IOSink? sink,
  Map<String, dynamic> item,
  List<String>? fields,
) {
  if (sink == null) return;
  final cols = fields ?? _defaultExportFields;
  final escaped = cols.map((f) => _csvEscape(item[f]));
  sink.writeln(escaped.join(','));
}

String _csvEscape(dynamic value) {
  if (value == null) return '';
  final s = value.toString();
  final mustQuote =
      s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r');
  var out = s.replaceAll('"', '""');
  if (mustQuote) out = '"' + out + '"';
  return out;
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (final a in args) {
    if (a.startsWith('--')) {
      final body = a.substring(2);
      final eq = body.indexOf('=');
      if (eq == -1) {
        map[body] = 'true';
      } else {
        map[body.substring(0, eq)] = body.substring(eq + 1);
      }
    }
  }
  return map;
}

class _StreamState {
  bool first = true;
}
